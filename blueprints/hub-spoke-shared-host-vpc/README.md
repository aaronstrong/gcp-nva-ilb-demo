# Hub and Spoke with a Shared Host VPC

Companion doc to [csr1000v-routing-documentation.md](./csr1000v-routing-documentation.md), which covers the CSR1000v routing
tables in detail. This doc describes the topology shown in the architecture diagram: the
GCP projects, VPCs, subnets, VMs, and how they connect.

## 1. Projects

| Project | Contains |
|---|---|
| `hub-project` | `vpc-untrusted`, `vpc-management`, `vpc-transit`, `vpc-hub1`, `vpc-hub1-spoke1`, `vpc-hub1-spoke2`, and the NVA instance group |
| `shared-vpc-project` | `shared-vpc` (Shared VPC host project, peered to `vpc-hub1`) |

## 2. Networks, subnets, and hosts

| VPC | Subnet | Host(s) | IP |
|---|---|---|---|
| `vpc-untrusted` | `subnet1-vpc-untrusted` | External Load Balancer; `vm-in-untrusted` | `172.16.5.10` |
| `vpc-management` | `subnet1-vpc-management` | `vm-in-management` | `172.16.3.10` |
| `vpc-transit` | `subnet1-vpc-transit` | HA Cloud VPN, Cloud Router; `vm-in-transit` | `172.16.4.10` |
| `vpc-hub1` | `subnet1-vpc-hub1` | `vm-in-hub1` | `172.16.1.10` |
| `vpc-hub1-spoke1` | `subnet1-vpc-hub1-spoke1` | `vm-in-hub1-spoke1` | `10.1.1.10` |
| `vpc-hub1-spoke2` | `subnet1-vpc-hub1-spoke2` | `vm-in-hub1-spoke2` | `10.1.2.10` |
| `shared-vpc` | `us-east1-sharedvpc-subnet` | `vm-in-shared-vpc` | `172.16.6.10` |
| On-prem network | — | On-prem VPN endpoint | `192.168.0.0/16` |

> **Diagram correction:** the diagram currently labels the host inside `shared-vpc` as
> `vm-in-hub2` at `172.16.2.10`. Per the actual Terraform (`google_compute_instance.vm-in-shared-vpc`,
> attached to `module.shared_vpc`), that host is `vm-in-shared-vpc` at `172.16.6.10` —
> `172.16.2.0/24` is hub2's (undeployed) range, not shared-vpc's. This looks like a leftover
> label from before the shared-vpc CIDR collision with hub2 was fixed earlier in this project;
> worth relabeling the box to avoid confusion later.

## 3. The NVA (`nva1` / `nva2`)

Both instances sit in managed instance group `ig-nvas` and run identical Cisco CSR1000v
configs behind per-VRF Internal Passthrough Load Balancers, giving active/active redundancy.

| GCP NIC | Cisco interface | Attached network | VRF |
|---|---|---|---|
| nic0 | GigabitEthernet1 | `vpc-untrusted` | Global table (NAT outside) |
| nic1 | GigabitEthernet2 | `vpc-management` | none configured — see note below |
| nic2 | GigabitEthernet3 | `vpc-transit` | `vrf-transit` |
| nic3 | GigabitEthernet4 | `vpc-hub1` | `vrf-hub1` |
| *(not attached)* | GigabitEthernet5 | `vpc-hub2` | `vrf-hub2` — configured but hub2 isn't deployed |

**Management's NIC:** the diagram shows `vpc-management` physically wired to the NVA
(nic1/GE2), and that NIC does exist on both instances. However, no VRF forwarding or static
routes are configured against GigabitEthernet2 in the startup script — management traffic
today flows entirely through its direct VPC peering to `vpc-transit`, not through the CSR.
The NIC is present but currently unused for routing.

## 4. How things connect

| Path | Mechanism |
|---|---|
| On-prem ⇄ `vpc-transit` | HA Cloud VPN + Cloud Router, terminated in `subnet1-vpc-transit` |
| `vpc-management` ⇄ `vpc-transit` | Direct VPC Peering — does not transit the NVA |
| `vpc-hub1-spoke1` ⇄ `vpc-hub1` | VPC Peering, but cross-network traffic (e.g. to spoke2, transit, shared-vpc) is forced through the NVA via a default route to the hub1 Internal LB |
| `vpc-hub1-spoke2` ⇄ `vpc-hub1` | Same pattern as spoke1 |
| `shared-vpc` ⇄ `vpc-hub1` | Direct VPC Peering (cross-project, Shared VPC). VM-to-VM traffic between these two doesn't touch the NVA at all; traffic to anywhere else from `shared-vpc` is forced through the NVA the same way the spokes are |
| `vpc-untrusted` | Internet egress point — NAT (PAT/overload) for `vrf-hub1` and `vrf-hub2` traffic exits here via GigabitEthernet1 |

## 5. What's not in this diagram
- `vpc-hub2` and its would-be spokes (`vpc-hub2-spoke1`, `vpc-hub2-spoke2`) are commented out
  in Terraform and not shown here — see the routing doc for the config that's already staged
  for them.
- The health-check source ranges (`35.191.0.0/16`, `130.211.0.0/22`) used by the Internal Load
  Balancers aren't part of the topology diagram, but are documented in the routing doc since
  they show up as routes on the NVA.

For the actual per-VRF route tables and worked traffic-path examples (e.g. shared-vpc ↔
on-prem, shared-vpc ↔ spoke1), see `csr1000v-routing-documentation.md`.

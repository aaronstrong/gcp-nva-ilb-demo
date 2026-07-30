# CSR1000v (nva1 / nva2) — Routing Documentation

Hub-and-spoke GCP network with a pair of Cisco CSR1000v NVAs (`nva1`, `nva2`) acting as the
central router/firewall between VPCs, an on-prem site (via HA/Classic VPN), and the internet.
`nva1` and `nva2` run identical configs and sit behind Internal Passthrough Network Load
Balancers (one per VRF-facing network) for active/active redundancy.

## 1. IP address plan

| Network | CIDR | Reachable via NVA interface | VRF |
|---|---|---|---|
| `vpc-untrusted` (internet egress / NAT) | `172.16.5.0/24` | GigabitEthernet1 | Global (no VRF) |
| `vpc-management` | `172.16.3.0/24` | GigabitEthernet2 | *(not routed through NVA — see §4)* |
| `vpc-transit` (HA/Classic VPN to on-prem) | `172.16.4.0/24` | GigabitEthernet3 | `vrf-transit` |
| `vpc-hub1` | `172.16.1.0/24` | GigabitEthernet4 | `vrf-hub1` |
| `vpc-hub2` | `172.16.2.0/24` | GigabitEthernet5 *(not yet deployed)* | `vrf-hub2` |
| `vpc-hub1-spoke1` | `10.1.1.0/24` | via GigabitEthernet4 (hub1) | summarized as `10.1.0.0/16` |
| `vpc-hub1-spoke2` | `10.1.2.0/24` | via GigabitEthernet4 (hub1) | summarized as `10.1.0.0/16` |
| `shared_vpc` (Shared VPC host project) | `172.16.6.0/24` | via GigabitEthernet4 (hub1) | peered directly to hub1, no dedicated NIC |
| On-prem (via HA VPN, terminated in `vpc-transit`) | `192.168.0.0/16` | via GigabitEthernet3 (transit) | reached through `vrf-transit`/`vrf-hub1` |
| GCP health-check ranges | `35.191.0.0/16`, `130.211.0.0/22` | — | used for ILB backend health checks |

**Note:** `shared_vpc` is peered directly to `vpc-hub1` (not attached to the NVA via its own
NIC). VM-to-VM traffic between `shared_vpc` and `vpc-hub1` itself flows over that direct
peering and never touches the CSR. Traffic from `shared_vpc` to anything else (spokes, transit,
on-prem) is forced through the NVA via a default route pointing at the hub1 Internal LB.

## 2. Why a multi-VRF design

Each spoke-facing network (`vpc-transit`, `vpc-hub1`, `vpc-hub2`) is placed in its own VRF on
the CSR. Since GCP VPC Peering is non-transitive, nothing outside a directly-peered network can
reach another VPC without passing through a router that has a leg in both — that's the NVA's
job. The VRFs keep each network's route table isolated so nothing leaks between security zones
except where explicitly routed (via interface-based static routes referencing another VRF's
interface — a lightweight route-leaking technique used throughout this config).

## 3. Interface summary

| Interface | Network | VRF | Role |
|---|---|---|---|
| GigabitEthernet1 | `vpc-untrusted` | Global table | Internet-facing; NAT overload (PAT) egress point for all VRFs |
| GigabitEthernet2 | `vpc-management` | *(unused on NVA)* | Present, but management is reached only via direct `vpc-transit` ↔ `vpc-management` peering, not through the CSR |
| GigabitEthernet3 | `vpc-transit` | `vrf-transit` | HA/Classic VPN termination network; on-prem connectivity |
| GigabitEthernet4 | `vpc-hub1` | `vrf-hub1` | Hub for spoke1, spoke2, and (via direct peering) `shared_vpc` |
| GigabitEthernet5 | `vpc-hub2` | `vrf-hub2` | Reserved for a second hub — **not currently attached to the instance** |

## 4. Routing tables (as configured)

### Global table (no VRF)
| Destination | Next Hop | Interface | Purpose |
|---|---|---|---|
| `0.0.0.0/0` | `172.16.5.1` | Gi1 | Default route to internet gateway (untrusted VPC) |
| `10.1.0.0/16` | `172.16.1.1` | Gi4 | Summary route to hub1's spokes (spoke1 + spoke2) |
| `172.16.1.0/24` | `172.16.1.1` | Gi4 | Route to hub1 subnet itself (hub1 lives in a VRF, so global table needs an explicit path) |
| `172.16.4.0/24` | `172.16.4.1` | Gi3 | Route to transit subnet itself (same reasoning) |

*(Global-table equivalents for hub2 — `10.2.0.0/16` via Gi5 and `172.16.2.0/24` via Gi5 — are
configured in Terraform but don't appear here because GigabitEthernet5 isn't an active interface
on the instance yet; a route can't install against a non-existent interface.)*

### `vrf-transit`
| Destination | Next Hop | Interface | Purpose |
|---|---|---|---|
| *(no default route)* | — | — | Transit intentionally has no path to the internet/global table |
| `10.1.0.0/16` | `172.16.1.1` | Gi4 | Reach hub1's spokes |
| `35.191.0.0/16` | `172.16.4.1` | Gi3 | GCP health-check source range — local return path |
| `130.211.0.0/22` | `172.16.4.1` | Gi3 | GCP health-check source range — local return path |
| `172.16.1.0/24` | `172.16.1.1` | Gi4 | Reach hub1 subnet (hub1 is in its own VRF) |
| `172.16.6.0/24` | `172.16.1.1` | Gi4 | Reach `shared_vpc` — needed for on-prem ⇄ shared-vpc return traffic |

### `vrf-hub1`
| Destination | Next Hop | Interface | Purpose |
|---|---|---|---|
| `0.0.0.0/0` | `172.16.5.1` | Gi1 *(leaked to global table)* | Internet-bound traffic falls through to global table for NAT egress |
| `10.1.0.0/16` | `172.16.1.1` | Gi4 | Local — hub1's own spokes |
| `35.191.0.0/16` | `172.16.1.1` | Gi4 | GCP health-check source range — local return path |
| `130.211.0.0/22` | `172.16.1.1` | Gi4 | GCP health-check source range — local return path |
| `172.16.4.0/24` | `172.16.4.1` | Gi3 | Reach transit subnet (transit is in its own VRF) |
| `172.16.6.0/24` | `172.16.1.1` | Gi4 | Reach `shared_vpc` (peered directly to hub1) |
| `192.168.0.0/16` | `172.16.4.1` | Gi3 | Reach on-prem via the HA VPN terminated in `vpc-transit` |

### `vrf-hub2` *(configured, not yet in active use — hub2 is not deployed)*
| Destination | Next Hop | Interface | Purpose |
|---|---|---|---|
| `0.0.0.0/0` | `172.16.5.1` | Gi1 *(leaked to global table)* | Same NAT-egress pattern as vrf-hub1 |
| `10.1.0.0/16` | `172.16.1.1` | Gi4 | Reach hub1's spokes |
| `172.16.1.0/24` | `172.16.1.1` | Gi4 | Reach hub1 subnet |
| `172.16.4.0/24` | `172.16.4.1` | Gi3 | Reach transit subnet |

## 5. End-to-end path examples

**`vm-in-shared-vpc` (172.16.6.10) → on-prem (192.168.2.99):**
`shared_vpc` default route → hub1 ILB → CSR Gi4 (`vrf-hub1`) → `192.168.0.0/16` route → Gi3 →
native `vpc-transit` route to VPN tunnel → on-prem.

**On-prem (192.168.2.99) → `vm-in-shared-vpc` (172.16.6.10):**
On-prem → VPN tunnel → `vpc-transit` default route → transit ILB → CSR Gi3 (`vrf-transit`) →
`172.16.6.0/24` route → Gi4 → hub1 → direct peering to `shared_vpc`.

**`vm-in-shared-vpc` → `vm-in-hub1-spoke1` (10.1.1.x):**
`shared_vpc` default route → hub1 ILB → CSR Gi4 (`vrf-hub1`) → `10.1.0.0/16` route → Gi4 (same
interface, different destination) → hub1 → direct peering to spoke1.

## 6. Known gaps / follow-ups
- **Hub2 is not active.** Its VRF and routes exist in config, but GigabitEthernet5 has no
  network interface attached to `nva1`/`nva2` yet. Re-enable the commented `network_interface`
  block and the corresponding Terraform resources for `vpc-hub2` when ready.
- **Management (`172.16.3.0/24`) is intentionally unreachable through the CSR** — it's only
  reachable via its direct peering to `vpc-transit`, by design.

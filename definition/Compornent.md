| 属性名              | 型                              |   必須 | 一意 | 例                              | 備考                     |
| ---------------- | ------------------------------ | ---: | -: | ------------------------------ | ---------------------- |
| Component Name   | Text                           |    ✓ |    | app-vm-01 / RDS-prod-01 / M365 | 名前                     |
| Component Type   | Select                         |    ✓ |    | IaaS                           | IaaS/PaaS/SaaS         |
| Parent Subsystem | Object reference（Subsystem）    |    ✓ |    | SUB-000456                     | 必須                     |
| Environment      | Select                         |    ✓ |    | Prod                           |                        |
| Owner            | User                           |    ✓ |    |                                | 運用責任                   |
| Location         | Select                         |      |    | AWS                            | DC/AWS/Azure/GCP/SaaS等 |
| Hostname         | Text                           |      |    | app-vm-01                      | IaaS向け                 |
| IP Address       | Text                           |      |    | 10.0.0.1                       | 任意                     |
| OS               | Object reference（OS）           | 条件必須 |    | RHEL9                          | **Type=IaaSなら必須**      |
| Middleware       | Object reference（Middleware）複数 |      |    | Tomcat 9                       | 任意                     |
| SaaS Tenant      | Object reference（SaaS Tenant）  | 条件必須 |    | M365-tenant-A                  | **Type=SaaSなら必須**      |
| Notes            | Text(複数行)                      |      |    |                                |                        |


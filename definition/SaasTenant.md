| 属性名            | 型                              | 必須 | 一意 | 例             | 備考          |
| -------------- | ------------------------------ | -: | -: | ------------- | ----------- |
| Tenant Name    | Text                           |  ✓ |  ✓ | M365-tenant-A | テナント識別      |
| Product        | Object reference（SaaS Product） |  ✓ |    | Microsoft 365 |             |
| Renewal Date   | Date                           |  ✓ |    | 2026-11-30    | **自動起票の基準** |
| Auto-Renew     | Select                         |  ✓ |    | Yes           | Yes/No      |
| SaaS Owner     | User                           |  ✓ |    |               | 責任者         |
| Admin Contact  | Text                           |    |    | it-admin@     | 任意          |
| Accounting Ref | Text/URL                       |    |    | PR-12345      | 経理側キー/リンク   |
| Notes          | Text(複数行)                      |    |    |               |             |


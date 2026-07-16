| 属性名                 | 型                                  | 必須 | 一意 | 例          | 備考         |
| ------------------- | ---------------------------------- | -: | -: | ---------- | ---------- |
| System ID           | Text                               |  ✓ |  ✓ | SYS-000123 | 表示ID       |
| System Name         | Text                               |  ✓ |    | 申込基盤       |            |
| Business Service    | Object reference（Business Service） |  ✓ |    | 顧客申込サービス   | 参照必須       |
| App Owner           | User                               |  ✓ |    |            | アプリ責任      |
| Infra Owner         | User                               |    |    |            | インフラ責任（任意） |
| Data Classification | Select                             |  ✓ |    | 個人情報あり     | 監査用途       |
| Lifecycle           | Select                             |  ✓ |    | Production | 開発/本番/廃止   |
| Notes               | Text(複数行)                          |    |    |            |            |


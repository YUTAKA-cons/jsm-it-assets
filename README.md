# IT Asset Management on Jira Service Managemet Assets

## Environment
API keyの作成
https://id.atlassian.com/manage-profile/security/api-tokens

## Export
### Export
Assets Export & masking
```
cd api
sh assets_export.sh
```

```
assets
├── api/           # API実行スクリプト
│   ├── .env
│   ├── assets_export.sh
│   ├── assets_json2md.sh
│   ├── assets_to_jira.sh
│   ├── assets_transfer.sh
│   ├── atlassian_config.sh
│   ├── atlassian_ids.sh
│   └── field_sync.log
│
├── json/           # 元データ
│   ├── IT-Schema/
│   │   ├── objecttypes_infra.json
│   │   └── objects_servers.json
│   ├── HR-Schema/
│   │   └── objecttypes_staff.json
│   ├── metadata.json
│   └── objectschema-list.json
│
├── json_masked/    # 【自動生成】マスク済みのJSON
│   ├── IT-Schema/
│   │   ├── objecttypes_infra.json
│   │   └── objects_servers.json
│   ├── HR-Schema/
│   │   └── objecttypes_staff.json
│   ├── metadata.json
│   └── objectschema-list.json
│
└── difinition/    # 【自動生成】objecttypesのみのMarkdown
    ├── IT-Schema/
    │   └── objecttypes_infra.md
    └── HR-Schema/
        └── objecttypes_staff.md
```

### JSON -> Markdown


### Data Transfer


## Create Jira Service Management


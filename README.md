# Backup tools

## Pufferpanel

The Pufferpanel servers are located in ${PUFFERPANEL_HOME}/servers.
Every server is identified with an <identifier>. For example : ${PUFFERPANEL_HOME}/servers/dffe1cd5

A Pufferpanel server backup name format is : `backup-${PUFFERPANEL_SERVER_IDENTIFIER}-${DATE}.tar.gz`.
The structure of a backup is the following, for example with `backup-dffe1cd5-2024-06-28_07-13-51.tar.gz` :
- `dffe1cd5/` : The server folder
- `dffe1cd5.json` : The server config
- `dffe1cd5.md5` : The server folder checksum

### Deploy a Pufferpanel backup

Use the deploy-backup script to deploy the backup.
For example :
```
./deploy-backup.sh 
```

## Generate backup

### Pufferpanel


## Deploy backup





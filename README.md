# EvmToolbox

## Quickstart using docker

```
docker build -t evm_toolbox .
docker run -it --env PHX_HOST=localhost --env SECRET_KEY_BASE="F6DLslylCXON4ehdkPyzdrPxt3tiNuKvdTNpSa/tZMI2QvVvwuRXAwFVKBRyxRiS" -p 4000:4000 evm_toolbox
```

You can now access to the tool via "http://localhost:4000"
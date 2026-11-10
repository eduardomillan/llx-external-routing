# Auto-detección de la red local

`EXTERNAL_IFACE` tiene su propia red local (p. ej. `192.168.1.0/24`: el router,
la impresora, un NAS...). Para que esos dispositivos sigan siendo alcanzables
mientras el resto del tráfico sale por `CORPORATE_IFACE`, esa red se detecta y
se enruta automáticamente a través de `EXTERNAL_IFACE`.

## Qué hace

- Se detecta el CIDR directamente conectado a `EXTERNAL_IFACE` (vía
  `ip -4 addr show dev $EXTERNAL_IFACE`).
- Se añade una ruta on-link a esa red en la tabla de routing (`ROUTING_TABLE`),
  para que no se intente alcanzar a través de la puerta de enlace externa.
- Se añade el CIDR a `IPS` en `config.conf`, igual que si se hubiera hecho con
  `llx-exroute-cli add ip <cidr>`. A partir de ahí aparece en
  `llx-exroute-cli list` / `get IPS` como cualquier otro destino configurado.

## Cuándo se ejecuta

- `llx-external-routing-dispatcher`: al conectar `EXTERNAL_IFACE` (evento `up`
  de NetworkManager).
- `refresh-external-routes`: en cada refresco periódico (timer systemd), con
  `EXTERNAL_IFACE` activo.

No se repite si el CIDR ya está en `IPS`, ni si fue excluido deliberadamente
(ver abajo).

## Exclusión deliberada (`EXCLUDED_IPS`)

Si se elimina esa red con:

```bash
sudo llx-exroute-cli remove ip 192.168.1.0/24
```

el CIDR se quita de `IPS` **y** se guarda en la nueva clave `EXCLUDED_IPS` de
`config.conf`. Esto evita que la auto-detección la vuelva a añadir, incluso si
`EXTERNAL_IFACE` se reconecta más tarde a otra red que resulte tener el mismo
CIDR.

```bash
llx-exroute-cli get EXCLUDED_IPS
```

`EXCLUDED_IPS` es de solo lectura desde la CLI (gestionada automáticamente, no
tiene un `set` dedicado); para "readmitir" una red basta con volver a añadirla
manualmente con `add ip <cidr>`.

## Archivos implicados

- `scripts/lib/common-routing.sh`: `detect_local_network`,
  `add_local_network_route`, `auto_add_local_network`, y las funciones
  compartidas `read_conf_var`/`write_conf_var` que usan para persistir en
  `config.conf`.
- `scripts/llx-external-routing-dispatcher` y `scripts/refresh-external-routes`:
  llaman a `auto_add_local_network` tras fijar la ruta por defecto en la tabla
  externa.
- `scripts/llx-exroute-cli`: `remove ip` persiste en `EXCLUDED_IPS`;
  `EXCLUDED_IPS` añadida a las claves consultables (`get`).
- `conf/config.conf`: nueva clave `EXCLUDED_IPS=""`.

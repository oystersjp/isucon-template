# isucon-template

## pprotein セットアップ

pprotein サーバは別途用意済みです。計測対象サーバと pprotein サーバで必要な作業を以下にまとめます。

### 計測対象サーバ（エージェント稼働サーバ）

```
cd /path/to/isucon-template
sudo mybin/pprotein/setup.sh install
```

- graphviz/gv（pprof グラフ描画用）と pprotein 本体/agent を取得し、systemd で `pprotein-agent` を起動します。`apt-get` が利用できない環境では graphviz/gv の導入はスキップされます。
- nginx / MySQL のログパスが異なる場合は、環境変数 `PPROTEIN_HTTPLOG` / `PPROTEIN_SLOWLOG` を指定してください。バージョンやアーキテクチャも環境変数で上書き可能です。
- 後片付けは `sudo mybin/pprotein/setup.sh uninstall` で行えます。

### pprotein サーバ（可視化・解析サーバ）

- alp（アクセスログ解析）と slp（スロークエリ解析）は pprotein サーバで管理します。例:

  ```
  ALP_VERSION=1.0.21
  ALP_ARCH=linux_amd64
  curl -fsSL "https://github.com/tkuchiki/alp/releases/download/v${ALP_VERSION}/alp_${ALP_VERSION}_${ALP_ARCH}.tar.gz" -o /tmp/alp.tar.gz
  tar -xzf /tmp/alp.tar.gz -C /tmp
  sudo install -m 0755 /tmp/alp /usr/local/bin/alp

  SLP_VERSION=0.2.1
  SLP_ARCH=linux_amd64
  curl -fsSL "https://github.com/tkuchiki/slp/releases/download/v${SLP_VERSION}/slp_${SLP_VERSION}_${SLP_ARCH}.tar.gz" -o /tmp/slp.tar.gz
  tar -xzf /tmp/slp.tar.gz -C /tmp
  sudo install -m 0755 /tmp/slp /usr/local/bin/slp
  ```

  ※バージョンやアーキテクチャは適宜読み替えてください。不要になった `/tmp/*.tar.gz` や展開物も削除して構いません。
- pprotein UI の `setting > group/targets` に対象サーバの Private IP と `http://<target>:19000` を登録し、必要に応じて `httplog/config` も調整してください。

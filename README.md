# isucon-template

## pprotein セットアップ

pprotein サーバは別途用意済みで、計測対象サーバ側でエージェントを動かしたい場合は `mybin/pprotein/setup.sh` を使います。

```
cd /path/to/isucon-template
sudo mybin/pprotein/setup.sh install
```

- 既定では `/home/isucon` 配下にバイナリを展開し、19000 番ポートで `pprotein-agent` を systemd サービスとして起動します。
- nginx / MySQL ログパスが異なる場合は、環境変数 `PPROTEIN_HTTPLOG` や `PPROTEIN_SLOWLOG` を指定して実行してください。
- 後片付けは `sudo mybin/pprotein/setup.sh uninstall` で行えます。
- pprotein UI の `setting > group/targets` に対象サーバの Private IP と `http://<target>:19000` を登録し、必要に応じて `httplog/config` も調整してください。

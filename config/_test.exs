use Mix.Config

config :stackns, config_file: File.cwd!() <> "/test/stackns.yml"
config :stackns, hosts_file:  File.cwd!() <> "/test/hosts"

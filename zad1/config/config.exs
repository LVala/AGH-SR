import Config

config :chat,
  address: :localhost,
  port: 4040,
  multicast_address: {224, 0, 0, 55},
  multicast_port: 5999

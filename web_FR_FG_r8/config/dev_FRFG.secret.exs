use Mix.Config

# Configure your database
config :risteys, Risteys.Repo,
  username: "sarakuitunen",
  password: "N0r5u_K4nt4",
  database: "risteys_fr_fg",
  hostname: "localhost",
  pool_size: 10

  # alternative configurations for importing data to GC SQL database
  #username: "postgres",
  #password: "8x!mnC*VZkWU5K#ZiaG5bQTCJpzH#Fhr$$x(^A^BBvi5oTFijNnhpzwz)#M!ACBq",
  ##database: "risteys_r8",
  #database: "risteys_r8_blue",
  #hostname: "35.205.171.61",
  #pool_size: 10

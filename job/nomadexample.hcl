job "sleep" {

  datacenters = ["dc1"]

  type = "system"

 group "sleepers" {

    restart {
      attempts = 2
      interval = "30m"
      delay = "15s"
      mode = "fail"
    }

    task "sleep" {
      driver = "raw_exec"
      user = "root"
      config {
        comand = "/usr/bin/sleep"
      }
      artifact {
        source = "http://nuc/sleep"
        destination = "/usr/bin/"
      }
    }
  }
}

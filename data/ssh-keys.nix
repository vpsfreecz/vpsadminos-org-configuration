rec {
  admins =
    aither.all
    ++
    [ martyet snajpa ];

  builders = [
    builder-int-vpsadminos-org
  ];

  aither = rec {
    ws = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDJL5CEMBEQA704OIgyg8/1WX4Z63gVXvvaIrz1jLSMlBdnE0daUdeD7NLCsV+RIZGywQj44im6lW8ahGdj4ivXHeLxaCCaWfzYMa2Q9AmQwJFQIrA8l+9c5bFaesMugaHJcEbS/hykuuaCyq8G77WSZVvoYVsM8Hte0hasEi5c6BrDY+54N01gnRdlkZ6Kw2HhGsh8jddAppapR69kA16Qn0FK9JMMY4WhoV7vOawn+RbpmryUP8B7rKcUFMXo1Q9ULF7igRLMpFDdG0OD9dIDv/WaRh8NKMFMUKsot9zONKf2krsjRNVjwBtY2RId1zkTseNrvjXcOjrp0VudG1t97VBqwIUm0ISnysfUz73hmVBvNPhE8yQ8Qy0Z3LVHxDWxH2mN8uwVXG8F16Z7n+Lgu8m8C8P+1wTGTbZtrtVYNwF+SpRNGrfVxI+RKFAIa9K+rZDR8THhO4MRhJuQlIEwhIBw3vSPxGrYODZv6vaEse/3wdi4Sztcv+n5MxrAn9mqfycE3LNXE2ZBQtXyxnKEq/XnPAcWJeLoLqKe4zehXoKKPXl5TcaTuv2UWpVDywGGwGoNucVLulMiUVE0F7At1G5h83lq78uVz2cJyNEwi2VkW72sgSlSKZgGtFwmGHKX1MlEZl5W/A9Tz0InnqRQUsSHg5gwOIjV9d+0IGvnyw== aither@orion";

    all = [ ws ];
  };

  martyet = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDP3Q9jQbk3X43Sv6yHFmnqzqBuYudbhdg/QHPbMaNBY5F9JPH0ThO4OdUI8nrMRaLhNFptEano/vSR+2/yPQJPtLoLArMBJHgWZ3NKgGsKuiCW8lIIWqagHVQQOsdUd/pizqTWI/G8yf4RIDllB6PDxGIcB++HIW9LVmOoGI0Fg+3LmnlhnQV81mPk2/9DKCQl2lnG1JQ3/e/851c0qaYVSW0KbQy5Br6JTh2mcUJO4FvtHCNsKW+s/bug23zMH/4rvo2CXsJbR+HNnAjS/OzPXz7BPunsU0GrJ3WpogSC4eFPN5Mtv4gz5pXZnAon0PAdyDxYoynRCd+ULjiSI6t1DOXg52SNFatdqUHVMKBi3+M7VTLSUgXtEEpA9cgRAyY4KYQ3SYfjuCP8DDNn/8s+k+tPdNHcafmE+iJ12IuFWXL+LCWvR0/K/iVbtLPBQW1Y5V0uoLXsmFeAVo8qny670sPJVl1a2AHkgccfw3tzC1Xk5bGBYgMEVxNLIQKu4DyPy1MiZi8oBgpAae1XDffrQ7hWWe3Tri+7VLrmJEC1/fRRzy7QwpTP9WOEMa8+ZQAf8ZNZvl9OcoS4axEhw7rnnJNTHWdetwxnhiqo7QsE7EL0+MC4geSadDnQKtzWdPBa3Z1N0XaxvWMhOTMpCaXnIy1wGfNnhe4xPvAyLr/a2Q== root@martyet-bjorn";

  snajpa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBK29/yHdxakVaJMYiIMBKb8nYGaj/gSQI4zErNVcbvsUpSiQuD+TLhIWYxR79D9rHFypMRm6aaEbeMHtw+TRjoI= snajpa@snajpaStation";

  builder-int-vpsadminos-org = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQDkpt1/DnuJvwH1+QPhyec+ltXiKuN0LagOfHzxesmOCRAFS4f2t9xJj7ck1n8hyHKJohlTp8DijhfuvHbIGpbtiRe0qcsVhvzk3lhWji9iR/yggAM2bondYwL3mnZ7MecI5qx/E++bDyO/p7Ue+cNzZShNAF9i8yWW+FOLgymoEuHbl5kpz/rZFSQBFRSLc2Bk5MlE+ohVn8QyQXoLwgeqQ85VnR8W4SxxVTh2qAbUX7vFtpx1dk2lpdEsAEwC9e794NSSN2kWMvnCd7acsLEqq4f5K+IxqN/PHvV6uhi05Tw2bbmVV+gvIpp+F4krvHXwpF1z07KlwAtnhJVRs+1fF39Zb2WPIU2HgtI+TfyV1F3R8gFmMiTX0p7ozsy+VzLep93KWgNQesNbSNrFKi/gaHi3/rH4V2kUkyP0evYSOAlU7+PtRRi0aOh5A3c8oDwgWPWnjcqLIrlfkdsznL0bJCvuRdfgxYN76K8BCqfSOc7W8EEJw5kvhu2Ey4lln4mm36VvxXOh1pVjGT9bPJ8DsoLlNKiYRXNgtBrNCwMmjjwNDyNnGnihZVu0VIMoks+2QsEEJ3c/8G9tY1tp46aG4km9lWEQ29GsJNYtwVdldQFlVLQVqeSlvmMqkfxAOcYHLXCp2nCPOgGxXH0Crf89B/bVG+B8Az0eVy/t+wPviQ== root@builder.int.vpsadminos.org";
}

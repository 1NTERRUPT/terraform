output "backstage IP:" {
  value = "${aws_instance.backstage.public_ip}"
}

output "scoreboard IP:" {
  value = "${aws_instance.scoreboard.private_ip}"
}

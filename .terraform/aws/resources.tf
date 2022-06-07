
resource "aws_instance" "web" {
  ami           = "ami-0ff8a91d"
  instance_type = "t2.micro"
  tags {
    Name = "HelloWorld"
  }
}

resource "aws_ebs_volume" "volume" {
  availability_zone = "us-east-1a"
  size              = 1
  tags {
    Name = "HelloWorld"
  }
}

resource "aws_volume_attachment" "volume_attachment" {
  device_name = "/dev/xvdf"
  volume_id   = "${aws_ebs_volume.volume.id}"
  instance_id = "${aws_instance.web.id}"
}

resource "aws_route53_record" "dns" {
  zone_id = "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
  name    = "test.example.com"
  type    = "A"
  ttl     = "300"
  records = ["${aws_instance.web.public_ip}"]
}

resource "aws_security_group" "firewall" {
  name        = "default"
  description = "Allow all inbound traffic by default"
  vpc_id      = "${aws_instance.web.vpc_id}"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "null_resource" "install_nginx" {
  connection {
    type        = "ssh"
    host        = "${aws_instance.web.public_ip}"
    user        = "root"
    private_key = "${file("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")}"
  }
  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y nginx",
      "service nginx start",
    ]
  }
}

resource "null_resource" "install_php" {
  connection {
    type        = "ssh"
    host        = "${aws_instance.web.public_ip}"
    user        = "root"
    private_key = "${file("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")}"
  }
  provisioner "remote-exec" {
    inline = [
      "apt update && apt install -y php8.0-fpm",
    ]
  }
}

resource "null_resource" "create_index" {
  connection {
    type        = "ssh"
    host        = "${aws_instance.web.public_ip}"
    user        = "root"
    private_key = "${file("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")}"
  }
  provisioner "remote-exec" {
    inline = [
      "echo '<?php echo \"Hello World!\" ?>' > /var/www/html/index.php",
    ]
  }
}

resource "null_resource" "configure_nginx" {
  connection {
    type        = "ssh"
    host        = "${aws_instance.web.public_ip}"
    user        = "root"
    private_key = "${file("XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX")}"
  }
  provisioner "remote-exec" {
    inline = [
      "rm /etc/nginx/sites-available/default",
      "tee /etc/nginx/sites-available/default <<EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    root /var/www/html;
    index index.php;
    server_name _;
    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php$ {
        fastcgi_pass unix:/var/run/php/php8.0-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}
EOF
      "
    ]
  }
}
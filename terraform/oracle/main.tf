resource "aws_security_group" "ssh" {
  name = "oracle-${var.name}-allow-ssh-sg"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = 22
    to_port = 22
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "spire" {
  name = "oracle-${var.name}-allow-spire-sg"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = var.spire_port
    to_port = var.spire_port
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ssb" {
  name = "oracle-${var.name}-allow-ssb-sg"

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port = var.ssb_port
    to_port = var.ssb_port
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "eth" {
  name = "oracle-${var.name}-allow-eth-sg"

  ingress {
    cidr_blocks = [
      "0.0.0.0/0"]
    from_port = var.eth_rpc_port
    to_port = var.eth_rpc_port
    protocol = "tcp"
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }
}

resource "aws_key_pair" "nixiform" {
  key_name = "oracle-${var.name}-nixiform"
  public_key = var.ssh_key
}

resource "aws_cloudwatch_log_group" "oracle" {
  name = "oracle-${var.name}-journal"

  tags = {
    Environment = "oracle-${var.name}"
    Application = "oracle"
  }
}

resource "aws_cloudwatch_dashboard" "oracle_nodes" {
  dashboard_name = "oracle-${var.name}-all-journal"
  dashboard_body = <<EOF
{
  "widgets": [
    {
      "type": "log",
      "x": 0,
      "y": 0,
      "width": 24,
      "height": 15,
      "properties": {
        "query": "SOURCE '${aws_cloudwatch_log_group.oracle.name}' | fields hostname, systemdUnit, @timestamp, message\n| sort @timestamp desc\n",
        "region": "${var.aws_region}",
        "stacked": false,
        "title": "Log group: ${aws_cloudwatch_log_group.oracle.name}",
        "view": "table"
      }
    }
  ]
}
EOF
}

resource "aws_iam_user" "oracle" {
  name = "oracle-${var.name}-journal"
  path = "/system/"
  tags = {
    Name = "oracle log"
  }
}

resource "aws_iam_access_key" "oracle" {
  user = aws_iam_user.oracle.name
}

resource "aws_iam_user_policy" "oracle_cloudwatch_rw" {
  name = "orcale-${var.name}-journald-cloudwatch-logs"
  user = aws_iam_user.oracle.name

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ],
      "Resource": [
        "arn:aws:logs:*:*:log-group:${aws_cloudwatch_log_group.oracle.name}",
        "arn:aws:logs:*:*:log-group:${aws_cloudwatch_log_group.oracle.name}:log-stream:*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": "es:ESHttpPost",
      "Resource": "arn:aws:es:*:*:*"
    }
  ]
}
EOF
}

resource "aws_instance" "feed" {
  count = var.feed_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.ssb.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "feed_${count.index}"
  }
}

resource "aws_instance" "feed_lb" {
  count = var.feed_lb_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.ssb.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "feed_lb_${count.index}"
  }
}

resource "aws_instance" "relay" {
  count = var.relay_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.ssb.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "relay_${count.index}"
  }
}

resource "aws_instance" "eth" {
  count = var.eth_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.eth.name,
    aws_security_group.ssb.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "eth_${count.index}"
  }
}

resource "aws_instance" "boot" {
  count = var.boot_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "boot_${count.index}"
  }
}

resource "aws_instance" "bb" {
  count = var.bb_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "bb_${count.index}"
  }
}
resource "aws_instance" "ghost" {
  count = var.ghost_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "ghost_${count.index}"
  }
}
resource "aws_instance" "spectre" {
  count = var.spectre_count
  ami = var.nixos_ami
  instance_type = var.instance_type
  key_name = aws_key_pair.nixiform.key_name
  security_groups = [
    aws_security_group.ssh.name,
    aws_security_group.spire.name
  ]
  root_block_device {
    volume_size = var.instance_volume_size
    encrypted = true
  }
  tags = {
    Environment = "oracle-${var.name}"
    Name = "spectre_${count.index}"
  }
}

output "nixiform" {
  value = concat(

  [for i, server in aws_instance.boot : {
    provider = "aws"
    name = server.tags.Name
    type = "boot"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    spire_port = var.spire_port
  }],
  [for i, server in aws_instance.bb : {
    provider = "aws"
    name = server.tags.Name
    type = "bb"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    spire_port = var.spire_port
  }],

  [for i, server in aws_instance.feed : {
    provider = "aws"
    name = server.tags.Name
    type = "feed"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    ssb_port = var.ssb_port
    spire_port = var.spire_port
  }],
  [for i, server in aws_instance.feed_lb : {
    provider = "aws"
    name = server.tags.Name
    type = "feed_lb"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    ssb_port = var.ssb_port
    spire_port = var.spire_port
  }],
  [for i, server in aws_instance.ghost : {
    provider = "aws"
    name = server.tags.Name
    type = "ghost"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    spire_port = var.spire_port
  }],

  [for i, server in aws_instance.relay : {
    provider = "aws"
    name = server.tags.Name
    type = "relay"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    ssb_port = var.ssb_port
    spire_port = var.spire_port
  }],
  [for i, server in aws_instance.spectre : {
    provider = "aws"
    name = server.tags.Name
    type = "spectre"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    spire_port = var.spire_port
  }],

  [for i, server in aws_instance.eth : {
    provider = "aws"
    name = server.tags.Name
    type = "eth"
    idx = i
    ip = server.public_ip
    ssh_key = var.ssh_key

    aws_access_key_id = aws_iam_access_key.oracle.id
    aws_secret_access_key = aws_iam_access_key.oracle.secret

    log_stream = "${server.tags.Name}-${server.id}"
    log_group = aws_cloudwatch_log_group.oracle.name

    eth_rpc_port = var.eth_rpc_port

    ssb_port = var.ssb_port
    spire_port = var.spire_port
  }]
  )
}

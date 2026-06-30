resource "aws_security_group" "ec2" {
  name        = "${local.full_prefix}-ec2-sg"
  description = "Allow HTTP from ALB"
  vpc_id      = aws_vpc.this.id

  ingress {
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_cf.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.full_prefix}-ec2-sg" })
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

resource "aws_iam_role" "ec2" {
  name = "${local.full_prefix}-ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = local.tags
}

resource "aws_iam_instance_profile" "ec2" {
  name = "${local.full_prefix}-ec2-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_instance" "app" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.private[0].id
  vpc_security_group_ids = [aws_security_group.ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ec2.name

  user_data = <<-EOF
    #!/bin/bash
    dnf install -y python3
    cat > /opt/app.py <<'PY'
    from http.server import BaseHTTPRequestHandler, HTTPServer
    import json, socket

    class Handler(BaseHTTPRequestHandler):
        def do_GET(self):
            if self.path.startswith('/health'):
                self.send_response(200)
                self.send_header('Content-Type','application/json')
                self.end_headers()
                self.wfile.write(json.dumps({'status':'ok','host':socket.gethostname(),'path':self.path}).encode())
                return
            self.send_response(200)
            self.send_header('Content-Type','text/html; charset=utf-8')
            self.end_headers()
            self.wfile.write(b'<h1>EERF Protected Service</h1><p>Origin application is healthy.</p>')
    HTTPServer(('0.0.0.0', 8080), Handler).serve_forever()
    PY
    cat > /etc/systemd/system/labapp.service <<'UNIT'
    [Unit]
    Description=EERF App
    After=network.target
    [Service]
    ExecStart=/usr/bin/python3 /opt/app.py
    Restart=always
    [Install]
    WantedBy=multi-user.target
    UNIT
    systemctl daemon-reload
    systemctl enable --now labapp
  EOF

  tags = merge(local.tags, { Name = "${local.full_prefix}-app" })
}

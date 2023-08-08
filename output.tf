output Ansible_Master_Server{
    value = [aws_instance.Ansible-Master.public_ip,aws_instance.Ansible-Master.private_ip]
}

output Windows_server-1 {
    value = aws_instance.Win-1.public_ip
}

output Windows_server-2 {
    value = aws_instance.Win-2.public_ip
}


output Windows_server-3{
    value = aws_instance.Win-3.public_ip
}

sudo usermod -aG docker $USER
newgrp docker
sudo service docker start
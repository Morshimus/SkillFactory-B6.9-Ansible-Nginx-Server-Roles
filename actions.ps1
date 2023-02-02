function ansible {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",
        [Parameter(Mandatory=$False)]
        [String]$server = "lemp",
        [Parameter(Mandatory=$False)]
        [String]$invFile = "./yandex_cloud.ini",
        [Parameter(Mandatory=$False)]
        [String]$privateKey = "~/.ssh/morsh_bastion_SSH",
        [Parameter(Mandatory=$False,Position=0)]
        [String]$args
    )
    wsl -d $distr -u $user -e ansible $server --inventory-file "$invFile" --private-key $privateKey $args
} 

Set-Alias ansible-playbook ansiblePlaybook
function ansiblePlaybook {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",        
        [Parameter(Mandatory=$False)]
        [String]$server = "lemp",
        [Parameter(Mandatory=$False)]
        [String]$invFile = "./yandex_cloud.ini",
        [Parameter(Mandatory=$False)]
        [String]$privateKey = "~/.ssh/morsh_bastion_SSH",
        [Parameter(Mandatory=$False)]
        [String]$Playbook = "./provisioning.yaml",
        [Parameter(Mandatory=$False,Position=0)]
        [string]$fileSecrets = '~/.vault_pass',
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$tagInit,
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$tagDrop,
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$secret
    )

    if($secret){$params='-e';$secrets = "'@secrets'"}

    if($tagInit){$params='--tags';$tag = "init postfix"}elseif($tagDrop){$param='--tags';$tag = "drop postfix"}

    wsl -d $distr -u $user -e ansible-playbook  -i "$invFile" --private-key $privateKey $params $secrets --vault-password-file=$fileSecrets  $Playbook  $param $tag
} 

Set-Alias ansible-vault ansibleVault
function ansibleVault {
    param (
        [Parameter(Mandatory=$False)]
        [string]$distr = "Ubuntu-20.04",
        [Parameter(Mandatory=$False)]
        [String]$user = "morsh92",
        [Parameter(Mandatory=$False,Position=0)]
        [String]$action = 'encrypt',
        [Parameter(Mandatory=$False,Position=0)]
        [String]$file = 'secrets',
        [Parameter(Mandatory=$False,Position=0)]
        [switch]$ask,
        [Parameter(Mandatory=$False,Position=0)]
        [string]$fileSecrets = '~/.vault_pass'

    )
    
    if($ask){$passwd = "--ask-vault-pass"}

    wsl -d $distr -u $user -e ansible-vault $action --vault-password-file=$fileSecrets $passwd $file
} 



function molecule {
    param (
        [Parameter(Mandatory=$False)]
        [string]$role = "nginx",
        [Parameter(Mandatory=$False)]
        [String]$org = "morsh92",
        [switch]$verify

    )
    
    $path = (Get-Location).path -replace "\\", "/"

    docker run -d --name=molecule-$role `
    -v  $path/molecule:/opt/molecule `
    --privileged `
    morsh92/molecule:dind
    
    docker exec -ti molecule-$role  /bin/sh -c  "molecule init role $org.$role -d docker"

    Copy-Item -Recurse -Force  $path/$role/tasks/* $path/molecule/$role/tasks

    Copy-Item -Recurse -Force  $path/$role/handlers/* $path/molecule/$role/handlers

    Copy-Item -Recurse -Force  $path/$role/templates/* $path/molecule/$role/templates

    Copy-Item -Recurse -Force  $path/$role/templates/* $path/molecule/$role/templates

    Copy-Item -Recurse -Force  $path/$role/tests/* $path/molecule/$role/tests

    Copy-Item -Recurse -Force  $path/$role/vars/* $path/molecule/$role/vars

    docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule create"

    docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule converge"

    if($verify){
    mkdir -p $path/molecule/$role/roles

    Copy-Item -Recurse -Force $path/ansible_tests/* $path/molecule/$role/roles
    
    docker exec -ti molecule-$role  /bin/sh -c  "cd ./$role && molecule verify"
     
    }

    docker rm molecule-$role -f

    Remove-Item -Recurse -Force $path/molecule/$role
} 
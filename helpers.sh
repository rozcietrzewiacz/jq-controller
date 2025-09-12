
UpdateCtrFile () 
{ 
    local f=$1;
    kubectl get cm jq-controller.sh -o json | jq --rawfile file "$f" '.data["'"$f"'"]=$file' | kubectl apply -f -
}

DiffCtrFile () 
{ 
    local f=$1;
    kubectl get cm jq-controller.sh -o json | jq --rawfile file "$f" '.data["'"$f"'"]=$file' | kubectl diff -f -
}

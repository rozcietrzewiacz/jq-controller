FROM bitnami/kubectl:latest

ADD controller.sh .

USER 1000:1000
#VOLUME /.kube/config
VOLUME /in
ENTRYPOINT ["./controller.sh"]

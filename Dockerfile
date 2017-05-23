FROM drydock/microbase:{{%TAG%}}

RUN mkdir -p /home/shippable/node
ADD . /home/shippable/node
ENTRYPOINT ["/home/shippable/node/boot.sh"]

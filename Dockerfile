FROM drydock/microbase:v5.5.3

RUN mkdir -p /home/shippable/node
ADD . /home/shippable/node
ENTRYPOINT ["/home/shippable/node/boot.sh"]

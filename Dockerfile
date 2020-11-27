FROM ppc64le/golang:alpine

ARG ANSIBLE_VERSION="2.10.2"
LABEL maintainer="bmarolleau"
LABEL ansible_version=${ANSIBLE_VERSION}

ENV GOPATH /go
ENV GOLANG_VERSION 1.9.4
ENV GOLANG_SRC_URL https://golang.org/dl/go$GOLANG_VERSION.src.tar.gz
ENV GOLANG_SRC_SHA256 0573a8df33168977185aa44173305e5a0450f55213600e94541604b75d46dc06

# for tf build versions available for ppc64le , refer to https://www.power-devops.com/terraform
ENV TERRAFORM_VERSION 0.12.28
ENV TERRAFORM_IBMCLOUD_VERSION 0.16.1
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

############ Ansible and dependencies

RUN set -ex \
	&& apk update \
	&& apk add --no-cache ca-certificates  \
	&& apk add --no-cache --virtual .build-deps \
	&& apk add --update bash gcc musl-dev openssl zip make bash git go curl py3-setuptools ansible curl py-pip python3 unzip \
        && pip3 install boto3 

############ Terraform on ppc64le

WORKDIR $GOPATH/bin
RUN wget https://dl.power-devops.com/terraform_${TERRAFORM_VERSION}_linux_ppc64le.zip
RUN unzip terraform_${TERRAFORM_VERSION}_linux_ppc64le.zip
RUN chmod +x terraform &&  rm -rf terraform_${TERRAFORM_VERSION}_linux_ppc64le.zip

############ Terraform : IBM Provider

RUN mkdir -p "$GOPATH/src" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
RUN mkdir -p $GOPATH/src/github.com/IBM-Cloud && cd $GOPATH/src/github.com/IBM-Cloud && git clone https://github.com/IBM-Cloud/terraform-provider-ibm.git --branch v$TERRAFORM_IBMCLOUD_VERSION
RUN cd $GOPATH/src/github.com/IBM-Cloud/terraform-provider-ibm && make fmt && make build   
RUN cd $GOPATH/src/github.com/IBM-Cloud/terraform-provider-ibm  cp $GOPATH/bin/terraform-provider-ibm  ~/.terraform.d/plugins/terraform-provider-ibm_v$TERRAFORM_IBMCLOUD_VERSION 
WORKDIR "/root"
RUN echo $' providers { \n \
ibm = "/go/bin/terraform-provider-ibm_v${TERRAFORM_IBMCLOUD_VERSION}" \n \
}' > /root/.terraformrc

############ Ansible Modules : IBM Cloud, AIX, IBM i

RUN ansible-galaxy collection install ibm.cloudcollection
RUN ansible-galaxy collection install ibm.power_ibmi
RUN ansible-galaxy collection install ibm.power_aix

EXPOSE 22
CMD    ["/bin/bash"]


FROM alpine:edge AS builder

WORKDIR ./

RUN apk update \
    && apk upgrade \
    && apk add --no-cache ca-certificates tzdata \
    libmsquic \
    dotnet10-sdk \
    git \
    curl

RUN git clone --depth 1 https://github.com/TechnitiumSoftware/TechnitiumLibrary.git  ./opt/technitium/TechnitiumLibrary
RUN git clone --depth 1 https://github.com/TechnitiumSoftware/DnsServer.git ./opt/technitium/DnsServer 
RUN cd ./opt/technitium \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.ByteTree/TechnitiumLibrary.ByteTree.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Net/TechnitiumLibrary.Net.csproj -c Release \
    && dotnet build TechnitiumLibrary/TechnitiumLibrary.Security.OTP/TechnitiumLibrary.Security.OTP.csproj -c Release \
    && dotnet publish DnsServer/DnsServerApp/DnsServerApp.csproj -c Release    

FROM alpine:edge

RUN apk add --no-cache aspnetcore10-runtime \
    libmsquic \
    doggo

RUN addgroup -S dns-server \
    && adduser -S -G dns-server dns-server

WORKDIR ./opt/technitium/dns
COPY --link --from=builder ./opt/technitium/DnsServer/DnsServerApp/bin/Release/publish ./opt/technitium/dns

RUN mkdir -p ./etc/dns ./var/lib/technitium ./usr/bin \
    && chown dns-server:dns-server ./etc/dns ./var/lib/technitium ./usr/bin/dotnet

VOLUME ["./etc/dns", "./var/lib/technitium", "./usr/bin"]

USER dns-server

EXPOSE 5380

ENTRYPOINT ["./usr/bin/dotnet", "./opt/technitium/dns/DnsServerApp.dll"]
CMD ["./opt/technitium/dns/start.sh", "-c", "./etc/dns"]

LABEL org.opencontainers.image.title="ASMGH-67 Private Homelab DNS"


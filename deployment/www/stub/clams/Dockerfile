FROM node:latest

RUN apt-get update && apt-get install tzdata -y
ENV TZ="America/New_York"

#RUN npm install -g npm@9.3.0

# Clone the repository
RUN git clone https://github.com/clams-tech/browser-app.git /usr/src/clams
WORKDIR /usr/src/clams

# checkout specific tag
RUN git -c advice.detachedHead=false checkout tags/1.2.0

# couldn't do a yarn build without updating this.
# RUN npx -y update-browserslist-db@latest


# install dependencies
RUN yarn

EXPOSE 4173

RUN mkdir /output
VOLUME /output

RUN yarn build

ENTRYPOINT [ "cp", "-a", "/usr/src/clams/.svelte-kit/output/.", "/output/" ]
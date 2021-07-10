FROM node:14

WORKDIR /usr/src/app

ENV PORT 3000

COPY package.json yarn.lock ./

RUN yarn install

COPY . .

EXPOSE 3000

CMD [ "node", "server.js" ]
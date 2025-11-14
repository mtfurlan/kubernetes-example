FROM node:25


EXPOSE 3000
WORKDIR /app
RUN npm i express

RUN cat <<EOF >> /app/server.js
const fs = require('node:fs');
const express = require('express')

const app = express()
const port = 3000


let annotations = {}
try {
    const annotationsStr = fs.readFileSync('/etc/podinfo/annotations', 'utf8');
    annotations = annotationsStr.split('\n').reduce((dict, el, i) => {
        const matches = el.match(/^(.*)="(.*)"$/);
        dict[matches[1]] = matches[2];
        return dict;
    }, {})
} catch (err) {
    console.error("failed to read annotations file, using empty");
    console.error(err);
}

app.get('/', (req, res) => {
    const node_name = process.env.NODE_NAME;
    const pod_name = process.env.POD_NAME;
    const pod_namespace = process.env.POD_NAMESPACE;
    const pod_ip = process.env.POD_IP;

    const headers = req.headers;

    const response = {
        node_name,
        pod_name,
        pod_namespace,
        pod_ip,
        gateway_api: req.headers["gateway-api"] ? true : false,
        annotations,
    };

    res.send(response)
})

app.listen(port, () => {
    console.log(`Example app listening on port ${port}`)
})
EOF
CMD ["node", "/app/server.js"]

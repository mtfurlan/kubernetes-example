FROM node:25


EXPOSE 3000
WORKDIR /app
RUN npm i express
RUN npm i prom-client express-prom-bundle

RUN cat <<EOF >> /app/server.js
const fs = require('node:fs');
const express = require('express')
const promBundle = require("express-prom-bundle");

const port = process.env.PORT | 3000;
const metricsPort = process.env.METRICS_PORT | 9797;

const app = express()
const metricsApp = express();

// Add the options to the prometheus middleware most option are for http_request_duration_seconds histogram metric
const metricsMiddleware = promBundle({
    autoregister: false,
    includeMethod: true,
    includePath: true,
    includeStatusCode: true,
    includeUp: true,
    customLabels: {project_name: 'hello_world', project_type: 'test_metrics_labels'},
    promClient: {
        collectDefaultMetrics: {
        }
    }
});


app.use(metricsMiddleware)
metricsApp.use(metricsMiddleware.metricsMiddleware);


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

    console.log(new Date().toISOString());
    //if(Math.random() >= 0.5) {
    //    res.status(500);
    //} else {
        res.status(200);
    //}
    res.send(response)
})

app.listen(port, () => {
    console.log("Example app listening on port " + port);
})
metricsApp.listen(metricsPort, () => {
    console.log("metrics listening on port " + metricsPort);
});
EOF
CMD ["node", "/app/server.js"]

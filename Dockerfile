FROM node:25


EXPOSE 3000
WORKDIR /app
RUN npm i express
RUN npm i prom-client express-prom-bundle
RUN npm i on-finished

RUN cat <<EOF >> /app/server.js
const fs = require('node:fs');
const express = require('express')
const promBundle = require("express-prom-bundle");
var onFinished = require('on-finished')

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

// define custom success rate metric
const promClient = promBundle.promClient;
new promClient.Gauge({
  name: 'request_success_rate',
  help: 'metric_help',
  collect() {
    if(success+failure == 0) {
        this.set(100);
    } else {
        this.set(success/(success+failure)*100);
    }
  },
});
new promClient.Gauge({
  name: 'requests',
  help: 'metric_help',
  collect() {
    this.set(success+failure);
  },
});

let success = 0;
let failure = 0;
// define function to look at all responses
const doMetrics = (statusCode) => {
    if(200 <= statusCode && statusCode < 300) {
        ++success;
    } else {
        ++failure;
    }
};

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


const handleRequest = (fail, req, res) => {
    onFinished(res, (err, res) => {
        doMetrics(res.statusCode);
    });
    const node_name = process.env.NODE_NAME;
    const pod_name = process.env.POD_NAME;
    const pod_namespace = process.env.POD_NAMESPACE;
    const pod_ip = process.env.POD_IP;

    const headers = req.headers;

    const response = {
        fail,
        node_name,
        pod_name,
        pod_namespace,
        pod_ip,
        gateway_api: req.headers["gateway-api"] ? true : false,
        annotations,
    };

    console.log(new Date().toISOString());
    if(fail) {
        res.status(500);
    } else {
        res.status(200);
    }
    res.send(response)
};
app.get('/', (req, res) => {
    return handleRequest(false, req, res);
})
app.get('/500', (req, res) => {
    return handleRequest(true, req, res);
})

app.listen(port, () => {
    console.log("Example app listening on port " + port);
})
metricsApp.listen(metricsPort, () => {
    console.log("metrics listening on port " + metricsPort);
});
EOF
CMD ["node", "/app/server.js"]

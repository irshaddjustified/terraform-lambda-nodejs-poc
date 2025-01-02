const express = require('express');
const app = express();

app.post('/healthcheck',(req,res)=>{
    res.status(200).send({message:'Hello, world!'});
})

module.exports = app
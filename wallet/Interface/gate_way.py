"""Author: Trinity Core Team 

MIT License

Copyright (c) 2018 Trinity

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE."""

import requests
from wallet.configure import Configure
from blockchain.interface import get_balance
from log import LOG
import json



def sync_channel(message_type, channel_name,founder, receiver, balance):
    message = {"MessageType": message_type,
               "MessageBody": {
                   "ChannelName": channel_name,
                   "Founder": founder,
                   "Receiver": receiver,
                   "Balance": balance
               ## deposit is like format : {${address_1}: {${asset_type}: amount}, ${address_2}: {${asset_type}: amount}}
                   ##${address_1} ${address_2} -- the node address of the channel bi-direction's owner
                   ##${asset_type} -- current just support "NEO", "TNC"
                  }
               }

    request = {
        "jsonrpc": "2.0",
        "method": "SyncChannel",
        "params": [message],
        "id": 1
    }
    result = requests.post(Configure["GatewayURL"], json=request)
    return result.json()



def join_gateway(publickey):
    balance = {}
    for i in Configure["AssetType"].keys():
        b = get_balance(publickey, i.upper())
        balance[i] = b
    message = {"MessageType":"SyncWallet",
               "MessageBody":{
                   "Publickey":publickey,
                   "CommitMinDeposit":Configure["CommitMinDeposit"],
                   "Fee":Configure["Fee"],
                   "alias":Configure["alias"],
                   "AutoCreate":Configure["AutoCreate"],
                   "MaxChannel":Configure["MaxChannel"],
                   "Balance":balance
                   }
               }
    request = {
        "jsonrpc": "2.0",
        "method": "SyncWalletData",
        "params": [message],
        "id": 1
    }
    result = requests.post(Configure["GatewayURL"], json=request)
    return result.json()


def get_router_info(message):
    request = {
        "jsonrpc": "2.0",
        "method": "GetRouterInfo",
        "params": [message],
        "id": 1
    }
    result = requests.post(Configure["GatewayURL"], json=request)
    return result.json()


def send_message(message):
    LOG.info("GateWay Send Message: {}".format(json.dumps(message)))
    request= {
            "jsonrpc": "2.0",
            "method": "TransactionMessage",
            "params": [message],
            "id": 1
    }
    result = requests.post(Configure["GatewayURL"], json=request)
    return result.json()





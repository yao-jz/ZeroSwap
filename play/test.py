import requests
import json

class Constants:
    EVENT_SCHEMA = "你的事件架构常量" # 从你的 JS 代码中替换
    UNIV3_POOL_UNI_WETH = "你的UNIV3_POOL_UNI_WETH常量" # 从你的 JS 代码中替换
    UNISWAP_UNIV_ROUTER_SEPOLIA = "你的UNISWAP_UNIV_ROUTER_SEPOLIA常量" # 从你的 JS 代码中替换
    # ELIGIBLE_BLOCK_HEIGHT = "你的ELIGIBLE_BLOCK_HEIGHT常量" # 从你的 JS 代码中替换
    NEXT_PUBLIC_ALCHEMY_URI_SEPOLIA = "https://eth-sepolia.g.alchemy.com/v2/ge59eYhLfKBYZnlaRVg9Lbkb8ZaJ3Tg9"

# def find_most_recent_uniswap_tx(address):
#     page_key = ""
#     while page_key is not None:
#         res = get_recent_txs(address, page_key)
#         recent_tx = res.get('transfers', [])
#         for tx in recent_tx:
#             receipt = get_recent_receipt(tx.get('hash'))
#             if receipt and len(receipt['logs']) > 0:
#                 for idx, log in enumerate(receipt['logs']):
#                     if (log['topics'][0] == Constants.EVENT_SCHEMA and
#                         log['topics'][2].lower() == bytes32(address.lower()) and
#                         log['address'].lower() == Constants.UNIV3_POOL_UNI_WETH):
#                         return {
#                             'blockNumber': str(int(log['blockNumber'], 16)),
#                             'txIdx': str(int(log['transactionIndex'], 16)),
#                             'logIdx': str(idx)
#                         }
#         page_key = res.get('pageKey')
#     print("Could not find any Transfer transaction")
#     return None

def get_recent_txs(address, page_key=None):
    params = {
        "fromBlock": hex(int(5000000)),
        "toBlock": "latest",
        # "fromAddress": address.lower(),
        # "toAddress": Constants.UNISWAP_UNIV_ROUTER_SEPOLIA,
        "toAddress": address.lower(),
        "withMetadata": True,
        "excludeZeroValue": False,
        "maxCount": "0x3e8",
        "order": "desc",
        "category": ["external"],
    }
    if page_key:
        params["pageKey"] = page_key
    response = requests.post(Constants.NEXT_PUBLIC_ALCHEMY_URI_SEPOLIA, json={
        "id": 1,
        "jsonrpc": "2.0",
        "method": "alchemy_getAssetTransfers",
        "params": [params]
    })
    return response.json().get('result')

def get_recent_receipt(hash):
    response = requests.post(Constants.NEXT_PUBLIC_ALCHEMY_URI_SEPOLIA, json={
        "id": 1,
        "jsonrpc": "2.0",
        "method": "eth_getTransactionReceipt",
        "params": [hash]
    })
    return response.json().get('result')

# 示例用法
address = "0x83c8c0B395850bA55c830451Cfaca4F2A667a983"
result = get_recent_txs(address)
print(result)

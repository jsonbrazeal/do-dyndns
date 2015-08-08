#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import json
import requests

with open('./api_key.txt', 'r') as f:
    api_key = f.read()
    print('got api_key: {}'.format(api_key), end='\n\n')

with open('./device_registration_id.txt', 'r') as f:
    reg_id = f.read()
    print('got reg_id: {}'.format(reg_id), end='\n\n')

data = {'message': 'hi'}

print('sending...')

headers = {'Authorization': 'key={}'.format(api_key),
           'Content-Type': 'application/json'}
data = {'registration_ids': [reg_id],
        'data': {'message': 'test!' }}
print('headers={}'.format(headers), end='\n')
print('data={}'.format(data), end='\n\n')
response = requests.post('https://android.googleapis.com/gcm/send', headers=headers, data=json.dumps(data))
print('sent...', end='\n\n')
print('response=')
print(response.text, end='\n\n')
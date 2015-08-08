from gcm import *

with open('./api_key.txt', 'r') as f:
    api_key = f.read()
    gcm = GCM(api_key)
    print('got api_key: {}'.format(api_key))

with open('./device_registration_id.txt', 'r') as f:
    reg_id = f.read()
    print('got reg_id: {}'.format(reg_id))

data = {'the_message': 'You have x new friends', 'param2': 'value2'}

print('sending...')
gcm.plaintext_request(registration_id=reg_id, data=data)
print('sent...')
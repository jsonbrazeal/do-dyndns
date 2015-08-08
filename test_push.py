from gcm import *

with open('./api_key.txt', 'r') as f:
    gcm = GCM(f.read())

with open('./device_registration_id.txt', 'r') as f:
    reg_id = f.read()

data = {'the_message': 'You have x new friends', 'param2': 'value2'}

gcm.plaintext_request(registration_id=reg_id, data=data)
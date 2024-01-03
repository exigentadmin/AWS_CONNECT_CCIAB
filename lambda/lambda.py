import random

def lambda_handler(event, context):
    x = random.randint(99999, 1000000)
    print (x)

    return x

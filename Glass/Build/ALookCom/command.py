
class Command:
    CFG_NAME_LEN = 12

    def __init__(self, com):
        self.__com = com
        self.longTimeout = (5 * 60) ## in seconds

    ## receive answer from a command
    def rcvAnswer(self, name, cmdId):
        rcv = self.__com.receiveFrame(cmdId)
        if not rcv['ret']:
            print(f"{name} failed to receive answer")
            return {'ret': False, 'data': [], 'query': []}

        ackOk = self.__com.receiveAck()
        if not ackOk:
            print(f"{name} failed to receive ack")
            return {'ret': False, 'data': [], 'query': []}
        
        return rcv

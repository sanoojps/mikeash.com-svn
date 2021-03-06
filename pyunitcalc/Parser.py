
from CalcException import CalcException
from DebugPrint import debugPrint
import Number
import Operator
import Tokenizer

import re


class Parser:
    def __init__(self, str):
        self.tokenizer = Tokenizer.Tokenizer(str)
        
        self.kOperator = "operator"
        self.kNumber = "number"
        
        self.unitRegex = re.compile("[a-zA-Z]")
        
        self.regexes = {
            re.compile("[-+\\*/\^()]|in$|to$"):	self.parseOperator,
            re.compile("[-+]?[0-9]+\\.?[0-9]*"):self.parseNumber,
            re.compile("[-+]?[0-9]*\\.?[0-9]+"):self.parseNumber,
            self.unitRegex:						self.parseUnit
        }
        
        self.parsingConversion = False 
    
    def nextToken(self):
        return self.tokenizer.nextToken()
    
    def parse(self):
        self.postfixStack = []
        self.infixStack = []
        self.lastValue = None
        while self.parseNextToken():
            pass
        while len(self.infixStack) > 0:
            self.postfixStack.append(self.infixStack.pop())
    
    def parseNextToken(self):
        t = self.nextToken()
        if t == None:
            return False
        return self.parseToken(t)
    
    def parseToken(self, t):
        debugPrint("parsing %s" % t)
        if (t == "in") or (t == "to"):
            self.parsingConversion = True
        if len(t) < 1:
            return False
        for r in self.regexes:
            if r.match(t):
                value = self.regexes[r](t)
                self.processValue(value)
                return True
        raise CalcException("unknown token %s" % t)
        return False
    
    def processValue(self, value):
        if value:
            value.process(self.infixStack, self.postfixStack)
            self.lastValue = value
    
    def parseNumber(self, t):
        return Number.Number(t, self.parsingConversion)
    
    def parseOperator(self, t):
        if t == '/' and self.unitRegex.match(self.tokenizer.peek()):
            return Operator.unitDivideOperator()
        elif t == '-' and not (self.lastValue and self.lastValue.isNumber()):
            self.parseToken('0')
            return Operator.unaryMinusOperator()
        else:
            return Operator.Operator(t)
    
    def parseUnit(self, t):
        if self.lastValue and self.lastValue.isNumber():
            self.processValue(Operator.unitMultiplyOperator())
        self.parseToken('1')
        self.lastValue.addUnitStr(t)
        return None
    
    def calc(self):
        debugPrint(str([x.__str__() for x in self.postfixStack]))
        finalStack = []
        for x in self.postfixStack:
            x.calc(finalStack)
        return finalStack[0]

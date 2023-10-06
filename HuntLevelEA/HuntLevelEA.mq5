//+------------------------------------------------------------------+
//|                                                  HuntLevelEA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#include<Trade\Trade.mqh>



//---
//--- Enums:
//---
enum SwingType {
   To_High=1,
   To_Low=-1,
   NONE=0
};

enum Position {
   BUY_POS=1,
   SELL_POS=-1
};
//+------------------------------------------------------------------+


//---
//--- structs
//---
class HuntLevel {
public:
   int               huntCandleIndex;
   bool              valid;
   bool              firstExit;
   bool              pullBackIn;
   bool              pullBackOut;
   string            lineName;
   int               position;
   void              nextCandle() {
      this.huntCandleIndex++;
   };
   void              print() {
      PrintFormat("HuntLevel:{ huntCandleIndex: %d , position: %s}",this.huntCandleIndex,this.position==BUY_POS?"BUY_POS":"SELL_POS");

   };

                     HuntLevel() {
      this.valid=true;
      this.firstExit=false;
      this.pullBackIn=false;
      this.pullBackOut=false;
      this.lineName="";
   };

};



// global variables

int lineIndex =1;
int huntLevelCount =0;

HuntLevel  _huntLevels[];
CTrade trade;


// generic inputs
input bool Debug_Mode = false;

// isGoodHuntCandle inputs
input int      Minimum_Shadow_Points                  =  1;
input double   Minimum_Shadow_Per_Body                =  1.5;
input int      Minimum_Gap_Point                      =  5;
input int      Minimum_Higher_Then_Last_n             =  10;
input int      Minimum_Hunted_Swings_Check_End        =  50;
input int      Minimum_Hunted_Swings_Check_Start      =  5;
input int      Minimum_HuntLevel_To_Pull_Back_Candles =  50;
input double   TP_per_SL                              =  0.5;
input int      Minimum_SL_from_hunt_shadow            =  10;



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
//---

//---
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---

   Print("Hunt Level Counts: "+huntLevelCount);


}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   if(isNewBar()) {
      //DebugBreak();
      increaseHuntCandleIndexes();
    
      int checkingIndex=1;

      openPosition();
      checkPricePullBackOut();
      checkPricePullBackIn();
      checkPriceFirstExit();

      findAndSaveHuntLevel(checkingIndex);


   }

   checkHuntLevelPriceCrossing();

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void findAndSaveHuntLevel(int checkingIndex) {
   if(isGoodHuntCandle(checkingIndex,SELL_POS)) {
      string lname = createVLine(clrRed,checkingIndex,STYLE_SOLID);
      huntLevelCount++;
      saveHuntLevel(checkingIndex,SELL_POS,lname);
   } else if(isGoodHuntCandle(checkingIndex,BUY_POS)) {
      string lname = createVLine(clrBlue,checkingIndex,STYLE_SOLID);
      huntLevelCount++;
      saveHuntLevel(checkingIndex,BUY_POS,lname);
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getTPSell(int huntCandleIndex) {
//return SymbolInfoDouble(_Symbol, SYMBOL_BID) - tp_points *_Point;
   double diff = NormalizeDouble(MathAbs(getSLSell(huntCandleIndex) - SymbolInfoDouble(_Symbol,SYMBOL_BID)),_Digits);
   return SymbolInfoDouble(_Symbol, SYMBOL_BID) - NormalizeDouble((diff*TP_per_SL),_Digits);

}

double getTPBuy(int huntCandleIndex){
return getHigh(huntCandleIndex)+50*_Point;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getSLSell(int huntCandleIndex) {
   double candleHigh = getHigh(huntCandleIndex);
   return candleHigh + 100 * _Point;
}

double getSLBuy(int huntCandleIndex){
return getLow(huntCandleIndex) - 40*_Point;

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openPosition() {
   int total = _huntLevels.Size();
   for(int i=0; i<total; i++) {
      if(_huntLevels[i].pullBackOut) {
         if(_huntLevels[i].position==SELL_POS) {
            trade.Sell(0.01,Symbol(),0,getSLSell(_huntLevels[i].huntCandleIndex),getTPSell(_huntLevels[i].huntCandleIndex));
            _huntLevels[i].valid=false;
         } else if(_huntLevels[i].position==BUY_POS) {
            DebugBreak();
            trade.Buy(0.01,Symbol(),0,getSLBuy(_huntLevels[i].huntCandleIndex),getTPBuy(_huntLevels[i].huntCandleIndex));
            _huntLevels[i].valid=false;
         }
      }
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkPricePullBackOut() {
   int total = _huntLevels.Size();
   for(int i=0; i<total; i++) {
      if(_huntLevels[i].pullBackIn&&_huntLevels[i].huntCandleIndex>1) {
         if(_huntLevels[i].position==SELL_POS) {
            if(getClose(1)<MathMax(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))) {
               _huntLevels[i].pullBackOut=true;
            }
         } else if(_huntLevels[i].position==BUY_POS) {
            if(getClose(1)>MathMin(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))) {
               _huntLevels[i].pullBackOut=true;
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkPricePullBackIn() {
   int total = _huntLevels.Size();
   for(int i=0; i<total; i++) {
      if(_huntLevels[i].firstExit &&_huntLevels[i].huntCandleIndex>1) {
         if(_huntLevels[i].position==SELL_POS) {
            if(
               getHigh(1)>MathMax(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))
               &&
               getHigh(1)<getHigh(_huntLevels[i].huntCandleIndex)
            ) {
               _huntLevels[i].pullBackIn=true;
            }
         } else if(_huntLevels[i].position==BUY_POS) {
            if(
               getLow(1)<MathMin(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))
               &&
               getLow(1)>getLow(_huntLevels[i].huntCandleIndex)
            ) {
               _huntLevels[i].pullBackIn=true;
            }
         }
      }
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkHuntLevelPriceCrossing() {
   int total = _huntLevels.Size();
   for(int i=0; i<total; i++) {
      _huntLevels[i].print();
      if(_huntLevels[i].position==SELL_POS) {
         if(getHigh(0)>getHigh(_huntLevels[i].huntCandleIndex)) {
            _huntLevels[i].valid= false;
         }
      } else {
         if(getLow(0)>getLow(_huntLevels[i].huntCandleIndex)) {
            _huntLevels[i].valid= false;
         }
      }
   }

}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void checkPriceFirstExit() {
   int total = _huntLevels.Size();
   PrintFormat("Checking NextCandle Of HuntLevels(count: %d) For First Exit PriceOut",total);
   for(int i=0; i<total; i++) {
      _huntLevels[i].print();
      if(_huntLevels[i].huntCandleIndex>1 && !_huntLevels[i].firstExit) {
         if(_huntLevels[i].position==SELL_POS) {
            if(getClose(1)<getOpen(1) && getClose(_huntLevels[i].huntCandleIndex)>getClose(1) && getOpen(1)<MathMax(getClose(_huntLevels[i].huntCandleIndex),getOpen(_huntLevels[i].huntCandleIndex)) && getBody(1)>getBody(_huntLevels[i].huntCandleIndex)) {
               _huntLevels[i].firstExit=true;
            } else {
               _huntLevels[i].valid= false;
            }
         } else if(_huntLevels[i].position==BUY_POS) {
            if(getClose(1)>getOpen(1) && getClose(_huntLevels[i].huntCandleIndex)<getClose(1) && getOpen(1)>MathMin(getClose(_huntLevels[i].huntCandleIndex),getOpen(_huntLevels[i].huntCandleIndex)) && getBody(1)>getBody(_huntLevels[i].huntCandleIndex)) {
               _huntLevels[i].firstExit=true;
            } else {
               _huntLevels[i].valid= false;
            }

         }
      }
   }
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void increaseHuntCandleIndexes() {
   int total = _huntLevels.Size();

   for(int i=0; i<total; i++) {
      if(!_huntLevels[i].valid || _huntLevels[i].huntCandleIndex > Minimum_HuntLevel_To_Pull_Back_Candles) {
         ObjectDelete(ChartID(),_huntLevels[i].lineName);
         ArrayRemove(_huntLevels,i,1);
         total = _huntLevels.Size();
      } else {
         _huntLevels[i].nextCandle();
      }
   }
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void saveHuntLevel(int huntLevelIndex,int position,string lname) {
   int i = ArraySize(_huntLevels);
   ArrayResize(_huntLevels,i+1);
   HuntLevel tmp;
   tmp.huntCandleIndex = huntLevelIndex;
   tmp.lineName = lname;
   tmp.position = position;
   _huntLevels[i]=tmp;
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getSwingsCount(double fromPrice, double untilPrice,int backCheckCount,int indexFrom,int swingType) {
   int res =0;
   double p =0.0;
   for(int i=indexFrom; i<indexFrom+backCheckCount+1; i++) {
      p = getAveragePrice(i);
      if(p<fromPrice || p>untilPrice|| indexFrom==iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,(i-indexFrom),indexFrom)) {
         continue;
      }
      if(getSwingType(i)==swingType) {
         res++;
      }
   }
   return res;
}


//+------------------------------------------------------------------+
//|  this Method used for recognizing swings and Swing types                                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getSwingType(int index) {

   double current = getHigh(index);
   double next = getHigh(index-1);
   double perviuse = getHigh(index+1);

   if(perviuse > current && next >current) {
      return To_High;
   } else if(perviuse < current && next <current) {
      return To_Low;
   } else {
      return NONE;
   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isGoodHuntCandle(int index,int position) {
   if(position==SELL_POS) {
      double upShadow = getUpShadow(index);
      double downShadow = getDownShadow(index);
      if(downShadow > upShadow) {
         printDebug("Down Shadow bigger then up Shadow and it's bad condition");
         return false;
      }
      double minUpShadow = NormalizeDouble(Minimum_Shadow_Points * _Point,_Digits);
      if(upShadow<minUpShadow) {
         printDebug("minUpShadow Value: "+minUpShadow +" up shadow : "+ getUpShadow(index)+" and it's bad condition");
         return false;
      }
      double shadowPerBody = getUpShadow(index) / MathMax(getBody(index),(1*_Point));
      if(shadowPerBody<Minimum_Shadow_Per_Body) {
         printDebug("shadowPerBody Value: "+shadowPerBody +" Minimum_Shadow_Per_Body : "+ Minimum_Shadow_Per_Body+" and it's bad condition");
         return false;
      }
      double upBand = getHigh(index);
      double lowBand = NormalizeDouble(MathMax(MathMax(getOpen(index),getClose(index)),MathMax(getOpen(index+1),getClose(index+1))),_Digits);
      int r =0;
      for(int i=index+Minimum_Hunted_Swings_Check_Start; i<Minimum_Hunted_Swings_Check_End+index+1; i++) {
         if(getHigh(i)<=upBand && getHigh(i)>= lowBand) {
            PrintFormat("Candle %s is inside Band:",IntegerToString(i));
            int hSwing = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,i-index+1,index);
            if(hSwing==index) {
               PrintFormat("From %s until %s Highies is %s",IntegerToString(index),IntegerToString(i),IntegerToString(hSwing));
               int sType = getSwingType(i);
               if(sType == To_Low) {
                  r++;
               }
            }
         }
      }

      if(r<1) {
         printDebug("No Hunted Swing found. bad condition.");
         return false;
      }

      return true;
   } else if(position==BUY_POS) {
      double upShadow = getUpShadow(index);
      double downShadow = getDownShadow(index);

      if(upShadow > downShadow) {
         printDebug("Up Shadow bigger then Down Shadow and it's bad condition");
         return false;
      }

      double minDownShadow = NormalizeDouble(Minimum_Shadow_Points * _Point,_Digits);

      if(downShadow<minDownShadow) {
         printDebug("mindownShadow Value: "+minDownShadow +" down shadow : "+ downShadow+" and it's bad condition");
         return false;
      }

      double shadowPerBody = NormalizeDouble(downShadow / MathMax(getBody(index),(1*_Point)),_Digits);
      if(shadowPerBody<Minimum_Shadow_Per_Body) {
         printDebug("shadowPerBody Value: "+shadowPerBody +" Minimum_Shadow_Per_Body : "+ Minimum_Shadow_Per_Body+" and it's bad condition");
         return false;
      }

      double upBand =NormalizeDouble(MathMin(MathMin(getOpen(index),getClose(index)),MathMin(getOpen(index+1),getClose(index+1))),_Digits);
      double lowBand =  getLow(index);
      int r =0;
      for(int i=index+Minimum_Hunted_Swings_Check_Start; i<Minimum_Hunted_Swings_Check_End+index+1; i++) {

         if(getLow(i)>=lowBand && getLow(i)<= upBand) {
            PrintFormat("Candle %s is inside Band:",IntegerToString(i));
            int hSwing = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,i-index+1,index);
            if(hSwing==index) {
               PrintFormat("From %s until %s Highies is %s",IntegerToString(index),IntegerToString(i),IntegerToString(hSwing));
               int sType = getSwingType(i);
               if(sType == To_High) {
                  r++;
               }

            }

         }
      }

      if(r<1) {
         printDebug("No Hunted Swing found. bad condition.");
         return false;
      }
      DebugBreak();
      return true;
   } else {
      return false;
   }

}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getAveragePrice(int index) {
   return  NormalizeDouble((getHigh(index)+getLow(index)+getClose(index)+getClose(index))/4,_Digits);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getUpShadow(int index) {
   double h = getHigh(index);
   double ocm = MathMax(getOpen(index),getClose(index));
   double res = h-ocm;
   return NormalizeDouble(res,_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getDownShadow(int index) {
   double h = getLow(index);
   double ocm = MathMin(getOpen(index),getClose(index));
   double res = ocm-h;
   return NormalizeDouble(res,_Digits);
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getBody(int index) {
   return NormalizeDouble(MathAbs(getOpen(index)-getClose(index)),_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getOpen(int index) {
   return NormalizeDouble(iOpen(_Symbol,PERIOD_CURRENT,index),_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getClose(int index) {
   return NormalizeDouble(iClose(_Symbol,PERIOD_CURRENT,index),_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getHigh(int index) {
   return NormalizeDouble(iHigh(_Symbol,PERIOD_CURRENT,index),_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getLow(int index) {
   return NormalizeDouble(iLow(_Symbol,PERIOD_CURRENT,index),_Digits);
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Returns true if a new bar has appeared for a symbol/period pair  |
//+------------------------------------------------------------------+
bool isNewBar() {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0) {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
   }

//--- if the time differs
   if(last_time!=lastbar_time) {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
   }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
string createVLine(int colorInteger,int shift,int style) {
   long chartId = ChartID();
   string name = "Lline";
   name = name + IntegerToString(lineIndex++);
   ObjectCreate(chartId,name,OBJ_VLINE,0,iTime(NULL,PERIOD_CURRENT,shift),0);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,style);
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,colorInteger);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,true);
   return name;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void createHLine(int colorInteger,double price) {
   long chartId = ChartID();
   string name = "Hline";
   name = name + IntegerToString(lineIndex++);
   ObjectCreate(chartId,name,OBJ_HLINE,0,0,price);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_DOT);
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,colorInteger);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,2);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,true);
}
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void printDebug(string s) {
   if(Debug_Mode) {
      Print(s);
   }
}
//+------------------------------------------------------------------+



//+------------------------------------------------------------------+

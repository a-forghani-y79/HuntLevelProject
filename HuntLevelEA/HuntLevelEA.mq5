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
int finalSell=0;
int finallBuy=0;

//debug vars
long longChecks=0;
long partOne=0;
long partTwo=0;
long partThree=0;
long partFour=0;
long trueBuy=0;

// indicator handlers

int ma=-1;



HuntLevel  _huntLevels[];
CTrade trade;


// generic inputs
input bool debug = false;
// isGoodHuntCandle inputs
input int      Minimum_Shadow_Points                  =  1;
input double   Minimum_Shadow_Per_Body                =  1.5;
input int      Minimum_Gap_Point                      =  5;
input int      Minimum_Hunted_Swings_Check_End        =  50;
input int      Minimum_Hunted_Swings_Check_Start      =  5;
input int      Minimum_HuntLevel_To_Pull_Back_Candles =  50;
input int      EMA_PERIOD                             =   7;
input double   Risk_Percent                           =  5;



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
//---
//---
   ma = iMA(_Symbol,PERIOD_CURRENT,EMA_PERIOD,0,MODE_EMA,PRICE_WEIGHTED);

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
//---

   PrintFormat("Hunt Level Counts: %d "+huntLevelCount);
   PrintFormat("Final Sell Positions: %d",finalSell);
   PrintFormat("Final Buy Positions: %d",finallBuy);
   Print("But positions:");
   PrintFormat("All %d",longChecks);
   PrintFormat("One %d",partOne);
   PrintFormat("Two %d",partTwo);
   PrintFormat("Three %d",partThree);
   PrintFormat("Four %d",partFour);
   PrintFormat("True Buy %d",trueBuy);
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
//---
   if(isNewBar()) {
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
   createVLine(clrRed,huntCandleIndex,STYLE_DASH);
   int tmp=huntCandleIndex+Minimum_Hunted_Swings_Check_Start, base =-1;
   do {
      tmp = getTrendMakerSwingIndex(tmp,SELL_POS);
      if(getLow(tmp)<SymbolInfoDouble(_Symbol,SYMBOL_BID)) {
         base = tmp;
      }

   } while(base ==-1);
   createHLine(clrViolet,getLow(base));
   createVLine(clrViolet,base,STYLE_DASH);
   return getLow(base);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getTPBuy(int huntCandleIndex) {
   createVLine(clrBlue,huntCandleIndex,STYLE_DASH);
   int tmp=huntCandleIndex+Minimum_Hunted_Swings_Check_Start , base =-1;
   do {
      tmp = getTrendMakerSwingIndex(tmp,BUY_POS);
      if(getHigh(tmp)>SymbolInfoDouble(_Symbol,SYMBOL_ASK)) {
         base = tmp;
      }

   } while(base ==-1);

   createHLine(clrYellow,getHigh(base));
   createVLine(clrYellow,base,STYLE_DASH);


   return getHigh(base);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getSLSell(int huntCandleIndex) {
   double candleHigh = getHigh(huntCandleIndex);
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   return NormalizeDouble(MathMax(candleHigh,ask)+50 *_Point,_Digits);
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getSLBuy(int huntCandleIndex) {

   double low = getLow(huntCandleIndex);
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   return NormalizeDouble(MathMin(low,bid)-50*_Point,_Digits);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getVolume(double riskPercent,double stoploss,int POSITION_TYPE) {
   double price = POSITION_TYPE==POSITION_TYPE_BUY?SymbolInfoDouble(_Symbol,SYMBOL_ASK):SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   int leverage = AccountInfoInteger(ACCOUNT_LEVERAGE);
   double volume = NormalizeDouble((riskPercent*balance) /(MathAbs(stoploss - price)*100*leverage),2);
   return volume;
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void openPosition() {
   int total = _huntLevels.Size();
   for(int i=0; i<total; i++) {
      if(_huntLevels[i].pullBackOut) {
         if(_huntLevels[i].position==SELL_POS) {
            double slSell = getSLSell(_huntLevels[i].huntCandleIndex);
            double volume = getVolume(Risk_Percent,slSell,POSITION_TYPE_SELL);
            PrintFormat("volume: %s",DoubleToString(volume,2));
            bool successTrade =trade.Sell(volume,Symbol(),0,slSell,getTPSell(_huntLevels[i].huntCandleIndex));
            _huntLevels[i].valid=false;
            finalSell++;
         } else if(_huntLevels[i].position==BUY_POS) {
            double slBuy = getSLBuy(_huntLevels[i].huntCandleIndex);
            double volume = getVolume(Risk_Percent,slBuy,POSITION_TYPE_SELL);
            PrintFormat("volume: %s",DoubleToString(volume,2));
            bool successTrade = trade.Buy(volume,Symbol(),0,slBuy,getTPBuy(_huntLevels[i].huntCandleIndex));
            finallBuy++;
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
            if(getClose(0)<MathMax(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))) {
               _huntLevels[i].pullBackOut=true;
            }
         } else if(_huntLevels[i].position==BUY_POS) {
            if(getClose(0)>MathMin(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))) {
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
               getClose(1)<MathMin(getOpen(_huntLevels[i].huntCandleIndex),getClose(_huntLevels[i].huntCandleIndex))
               &&
               getClose(1)>getLow(_huntLevels[i].huntCandleIndex)
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

      if(_huntLevels[i].position==SELL_POS) {
         if(getHigh(0)>getHigh(_huntLevels[i].huntCandleIndex)) {
            if(debug)
               PrintFormat("HuntLevel index %d Invalidate based On Price Crossing.",_huntLevels[i].huntCandleIndex);
            _huntLevels[i].valid= false;
         }
      } else {
         if(getLow(0)<getLow(_huntLevels[i].huntCandleIndex)) {
            if(debug)
               PrintFormat("HuntLevel index %d Invalidate based On Price Crossing.",_huntLevels[i].huntCandleIndex);
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
   for(int i=0; i<total; i++) {
      if(_huntLevels[i].huntCandleIndex>1 && !_huntLevels[i].firstExit) {
         if(_huntLevels[i].position==SELL_POS) {
            if(getClose(1)<getOpen(1) && getClose(_huntLevels[i].huntCandleIndex)>getClose(1) && getOpen(1)<MathMax(getClose(_huntLevels[i].huntCandleIndex),getOpen(_huntLevels[i].huntCandleIndex)) && getBody(1)>getBody(_huntLevels[i].huntCandleIndex)) {
               _huntLevels[i].firstExit=true;
            } else {
               if(debug)
                  PrintFormat("HuntLevel index %d Invalidate based On first price Exit.",_huntLevels[i].huntCandleIndex);
               _huntLevels[i].valid= false;
            }
         } else if(_huntLevels[i].position==BUY_POS) {
            if(getClose(1)>getOpen(1)
                  && getClose(_huntLevels[i].huntCandleIndex)<getClose(1)
                  && getOpen(1)>MathMin(getClose(_huntLevels[i].huntCandleIndex),getOpen(_huntLevels[i].huntCandleIndex)) &&
                  getBody(1)>getBody(_huntLevels[i].huntCandleIndex)) {
               _huntLevels[i].firstExit=true;
            } else {
               if(debug)
                  PrintFormat("HuntLevel index %d Invalidate based On first price Exit.",_huntLevels[i].huntCandleIndex);
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
int getTrendMakerSwingIndex(int start,int position) {
   int previous,current=start;
   do {
      current++;
      previous = current+1;

      if(position==BUY_POS) {
         if(
            getEMA_Weighted(current)>getEMA_Weighted(previous)
         ) {
            break;
         }
      } else  if(position==SELL_POS) {
         if(
            getEMA_Weighted(current)<getEMA_Weighted(previous)
         ) {
            break;
         }
      }

   } while(true);

   return current;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double getEMA_Weighted(int index) {
   double data[];
   ArraySetAsSeries(data, true);
   CopyBuffer(ma, 0, index, index+1, data);
   return data[0];
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
         return false;
      }
      double minUpShadow = NormalizeDouble(Minimum_Shadow_Points * _Point,_Digits);
      if(upShadow<minUpShadow) {
         return false;
      }
      double shadowPerBody = getUpShadow(index) / MathMax(getBody(index),(1*_Point));
      if(shadowPerBody<Minimum_Shadow_Per_Body) {
         return false;
      }
      double upBand = getHigh(index);
      double lowBand = NormalizeDouble(MathMax(MathMax(getOpen(index),getClose(index)),MathMax(getOpen(index+1),getClose(index+1))),_Digits);
      int r =0;
      for(int i=index+Minimum_Hunted_Swings_Check_Start; i<Minimum_Hunted_Swings_Check_End+index+1; i++) {
         if(getHigh(i)<=upBand && getHigh(i)>= lowBand) {
            int hSwing = iHighest(_Symbol,PERIOD_CURRENT,MODE_HIGH,i-index+1,index);
            if(hSwing==index) {
               int sType = getSwingType(i);
               if(sType == To_Low) {
                  r++;
               }
            }
         }
      }

      if(r<1) {
         return false;
      }
      if(debug)
         Print("New HuntLevelFound");
      return true;
   } else if(position==BUY_POS) {

      longChecks++;
      double upShadow = getUpShadow(index);
      double downShadow = getDownShadow(index);

      if(upShadow > downShadow) {
         partOne++;
         return false;
      }

      double minDownShadow = NormalizeDouble(Minimum_Shadow_Points * _Point,_Digits);

      if(downShadow<minDownShadow) {
         partTwo++;
         return false;
      }

      double shadowPerBody = NormalizeDouble(downShadow / MathMax(getBody(index),(1*_Point)),_Digits);
      if(shadowPerBody<Minimum_Shadow_Per_Body) {
         partThree++;
         return false;
      }

      double upBand =NormalizeDouble(MathMax(MathMax(getOpen(index),getClose(index)),MathMax(getOpen(index+1),getClose(index+1))),_Digits);
      double lowBand =  getLow(index);
      int r =0;
      for(int i=index+Minimum_Hunted_Swings_Check_Start; i<Minimum_Hunted_Swings_Check_End+index+1; i++) {

         if(getLow(i)>=lowBand && getLow(i)<= upBand) {
            int hSwing = iLowest(_Symbol,PERIOD_CURRENT,MODE_LOW,i-index+1,index);
            if(hSwing==index) {
               int sType = getSwingType(i);
               if(sType == To_High) {
                  r++;
               }
            }
         }
      }

      if(r<1) {
         partFour++;
         return false;
      }
      trueBuy++;
      if(debug)//---

         Print("New HuntLevelFound");
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
void printCandle(int index) {
   PrintFormat("index: %d, High: %f, Open: %f, Close: %f, Low: %f",index,getHigh(index),getOpen(index),getClose(index),getLow(index));
}
//+------------------------------------------------------------------+

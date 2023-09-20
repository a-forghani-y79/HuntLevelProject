//+------------------------------------------------------------------+
//|                                                  HuntLevelEA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

// global variables

int lineIndex =1;
int huntLevelCount =0;


// generic inputs
input bool Debug_Mode = false;

// isGoodHuntCandle inputs
input int      Minimum_Shadow_Points      =  10;
input double   Minimum_Shadow_Per_Body    =  1.5;
input int      Minimum_Gap_Point          =  5;
input int      Minimum_Higher_Then_Last_n =  30;



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

      // its just for sell positions
      int checkingIndex=2;
      // may be it should be 2, because we should check exit point and gap with second next candle

      // find hunt level candle
      if(isGoodHuntCandle(checkingIndex)) {

         createVLine(clrAliceBlue,checkingIndex);
         huntLevelCount++;

         // flash back and find the base and reason of that shadow
         // by checking MA on typicalPrice and Period duration 1 or 2
         int baseIndexHuntCandle = getBaseCandleIndexOf(checkingIndex);

         printDebug("base index is : "+baseIndexHuntCandle);

         double highBand = getHigh(checkingIndex);
         double lowBand = getLow(baseIndexHuntCandle);


//
//
//         // iterate history candels and count swings between two prices(hunted-swings):
//         // high band is qeual to high of hunt candle
//         // low band is equal to low of base candle that we found in pervious step
//         // we should not have any swing or candle upper then uo band price that means hunt candle shuld higher then n-th last candle
//         // based in hunted-swings count we can invest on hunt level
//         int huntedSwingCount = getHuntedSwingCount(highBand,lowBand);
//
//         // save hunt level candle
//         saveTheHuntLevel(checkingIndex,huntedSwingCount);
      }
   }


// wait until the price come back into hunt level(that means price cross into price range[hunt candle low, hunt candle high] and come out from price range and go down)
// after cross, we shuld get confirmation from 5Min, then we can submit sell position

//   if(isPrinceCrossWithAnyHuntLevel()) {
//      int crossedHuntLevelCandleIndex = getCrossedHuntLevelCandleIndex();
//
//      if(is5MinConfirmedSellPosition()) {
//         submitSellPosition(crossedHuntLevelCandleIndex);
//      }
//
//
//   }

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isGoodHuntCandle(int index) {
//that has good shadow and it shuld have a good Gap and strong exit
   printDebug("Checking...");

   double minUpShadow = NormalizeDouble(Minimum_Shadow_Points * _Point,_Digits);
   if(getUpShadow(index)<minUpShadow) {
      printDebug("minUpShadow Value: "+minUpShadow +" up shadow : "+ getUpShadow(index)+" and it's bad condition");
      return false;
   }

   int indexHighestNth = iHighest(Symbol(),PERIOD_CURRENT,MODE_HIGH,Minimum_Higher_Then_Last_n,index);
   if(indexHighestNth!= index) {
      printDebug("indexHighestNth Value: "+indexHighestNth +" index : "+ index+" and it's bad condition");
      return false;
   }


   double shadowPerBody = getUpShadow(index) / MathMax(getBody(index),(1*_Point));
   if(shadowPerBody<Minimum_Shadow_Per_Body) {
      printDebug("shadowPerBody Value: "+shadowPerBody +" Minimum_Shadow_Per_Body : "+ Minimum_Shadow_Per_Body+" and it's bad condition");
      return false;
   }

   double gap = NormalizeDouble(getClose(index)-getOpen(index-2),_Digits);
   if(gap < Minimum_Gap_Point *_Point) {
      printDebug("gap Value: "+gap +" Minimum_Gap_Point : "+ Minimum_Gap_Point+" and it's bad condition");
      return false;
   }

   return true;

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int getBaseCandleIndexOf(int index) {
   int result = index;
   double tmp =NormalizeDouble((getAveragePrice(index)+getAveragePrice(index+1))/2,_Digits);

   for(int i=index; i<500; i++) {
      if(NormalizeDouble((getAveragePrice(i)+getAveragePrice(i+1))/2,_Digits)>tmp) {
         result = i;
         break;
      } else {
         tmp = NormalizeDouble((getAveragePrice(i)+getAveragePrice(i+1))/2,_Digits);
      }
   }
   if(result< index+4)
     {
      return getBaseCandleIndexOf(index+1);
     }
   return result;
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
   return NormalizeDouble(MathAbs(getHigh(index)-MathMax(getOpen(index),getClose(index))),_Digits);
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
void createVLine(int colorInteger,int shift) {
   long chartId = ChartID();
   string name = "Lline";
   name = name + IntegerToString(lineIndex++);
   ObjectCreate(chartId,name,OBJ_VLINE,0,iTime(NULL,PERIOD_CURRENT,shift),0);
   ObjectSetInteger(chartId,name,OBJPROP_STYLE,STYLE_DASH);
   ObjectSetInteger(chartId,name,OBJPROP_COLOR,colorInteger);
   ObjectSetInteger(chartId,name,OBJPROP_WIDTH,1);
   ObjectSetInteger(chartId,name,OBJPROP_BACK,true);
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

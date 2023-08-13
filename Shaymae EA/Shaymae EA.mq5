//+------------------------------------------------------------------+
//|                                                   Shaymae EA.mq5 |
//|                               Copyright 2023, Khaireddine DALAA. |
//|                                         https://www.lyfyteck.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input int NumberOfCandles = 1000; // User-defined input for the number of candles
input int RSILength = 12; // Length for RSI calculation
input int EMALength = 150; // Length for EMA calculation
input int BackCandles = 15; // Number of candles to look back

input string dotName = "PivotPointDots"; // Unique name for the dot objects
int pivotPoints[]; // Array to store pivot points
double pointPositions[]; // Array to store point positions
double openPrices[];
double closePrices[];
double highPrices[];
double lowPrices[];
double rsiValues[];
double emaValues[];
int EMASignal[];
ENUM_TIMEFRAMES period = Period(); // Current timeframe
string symbol = Symbol(); // Current symbol

datetime lastLoadedTime = 0; // Stores the open time of the last loaded candle

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   Alert(lastLoadedTime);
// Initial load
   LoadCandles();
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

// Check if a new candle has formed
   if(TimeCurrent() != lastLoadedTime)
     {
      LoadCandles();
     }
// Your trading logic here
  }

// Function to load the last NumberOfCandles candles and calculate RSI and EMA
void LoadCandles()
  {
   ArraySetAsSeries(openPrices, true);
   ArraySetAsSeries(closePrices, true);
   ArraySetAsSeries(highPrices, true);
   ArraySetAsSeries(lowPrices, true);
   ArraySetAsSeries(rsiValues, true);
   ArraySetAsSeries(emaValues, true);
   ArraySetAsSeries(EMASignal, true);

   ArrayResize(openPrices, NumberOfCandles);
   ArrayResize(closePrices, NumberOfCandles);
   ArrayResize(highPrices, NumberOfCandles);
   ArrayResize(lowPrices, NumberOfCandles);
   ArrayResize(rsiValues, NumberOfCandles);
   ArrayResize(emaValues, NumberOfCandles);
   ArrayResize(EMASignal, NumberOfCandles);

   for(int i = 0; i < NumberOfCandles; i++)
     {
      openPrices[i] = iOpen(symbol, period, i);
      closePrices[i] = iClose(symbol, period, i);
      highPrices[i] = iHigh(symbol, period, i);
      lowPrices[i] = iLow(symbol, period, i);
      rsiValues[i] = iRSI(symbol, period, RSILength, i);
      emaValues[i] = iMA(symbol, period, EMALength, 0, MODE_EMA, i);

     }
// Pivot Logic
   ArraySetAsSeries(pivotPoints, true);
   ArrayResize(pivotPoints, NumberOfCandles);

   int window = BackCandles; // Window size for pivot detection (you can adjust this value)
   for(int i = 0; i < NumberOfCandles; i++)
     {
      pivotPoints[i] = isPivot(i, window);
     }
// Apply trend detection logic
   for(int row = BackCandles; row < NumberOfCandles; row++)
     {
      int upt = 1;
      int dnt = 1;
      for(int i = row - BackCandles; i <= row; i++)
        {
         if(MathMax(openPrices[i], closePrices[i]) >= emaValues[i])
           {
            dnt = 0;
           }
         if(MathMin(openPrices[i], closePrices[i]) <= emaValues[i])
           {
            upt = 0;
           }
        }
      if(upt == 1 && dnt == 1)
        {
         EMASignal[row] = 3;
        }
      else
         if(upt == 1)
           {
            EMASignal[row] = 2;
           }
         else
            if(dnt == 1)
              {
               EMASignal[row] = 1;
              }
     }

// to plot points
   ArraySetAsSeries(pointPositions, true);
   ArrayResize(pointPositions, NumberOfCandles);

   for(int i = 0; i < NumberOfCandles; i++)
     {
      pointPositions[i] = pointPos(pivotPoints[i], highPrices[i], lowPrices[i]);
     }
// Delete existing points
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, OBJ_TREND);
      if(StringFind(name, dotName) != -1)
        {
         ObjectDelete(0, name);
        }
     }
// Plot the points
// Plot the points
   for(int i = 0; i < NumberOfCandles; i++)
     {
      if(pointPositions[i] != EMPTY_VALUE)
        {
         datetime time = iTime(symbol, period, i);
         string pointObjectName = dotName + IntegerToString(i);
         ObjectCreate(0, pointObjectName, OBJ_ARROW, 0, time, pointPositions[i]);

         // Check for CHOCH pattern
         color pointColor = clrRed; // Default color
         if(detect_structure(i, BackCandles, window) == 1)
           {
            pointColor = clrYellow; // Change color if pattern detected
            pointObjectName = "Yellow "+ dotName + IntegerToString(i);
           }

         ObjectSetInteger(0, pointObjectName, OBJPROP_COLOR, pointColor); // Set the color of the point
         ObjectSetInteger(0, pointObjectName, OBJPROP_ARROWCODE, 159); // Set the arrow code to a dot-like symbol
        }
     }

   lastLoadedTime = TimeCurrent(); // Update the time of the last loaded candle
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int isPivot(int candle, int window)
  {
   if(candle - window < 0 || candle + window >= ArraySize(openPrices))
     {
      return 0;
     }

   int pivotHigh = 1;
   int pivotLow = 2;
   for(int i = candle - window; i <= candle + window; i++)
     {
      if(lowPrices[candle] > lowPrices[i])
        {
         pivotLow = 0;
        }
      if(highPrices[candle] < highPrices[i])
        {
         pivotHigh = 0;
        }
     }
   if(pivotHigh && pivotLow)
     {
      return 3;
     }
   else
      if(pivotHigh)
        {
         return pivotHigh;
        }
      else
         if(pivotLow)
           {
            return pivotLow;
           }
         else
           {
            return 0;
           }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double pointPos(int pivotType, double high, double low)
  {
   if(pivotType == 2)
     {
      return low - 0.0001;
     }
   else
      if(pivotType == 1)
        {
         return high + 0.0005;
        }
      else
        {
         return EMPTY_VALUE;
        }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int detect_structure(int candle, int backcandles, int window)
  {
   if(window <= backcandles || candle - backcandles - window < 0)
     {
      return 0; // Ensure window is greater than the pivot window and within bounds
     }

   double highs[3];
   int idxhighs[3];
   double lows[3];
   int idxlows[3];
   int highCount = 0, lowCount = 0;

   for(int i = candle - backcandles - window; i < candle - window; i++)
     {
      if(pivotPoints[i] == 1 && highCount < 3)
        {
         highs[highCount] = highPrices[i];
         idxhighs[highCount] = i;
         highCount++;
        }
      if(pivotPoints[i] == 2 && lowCount < 3)
        {
         lows[lowCount] = lowPrices[i];
         idxlows[lowCount] = i;
         lowCount++;
        }
     }

   double lim1 = 0.005;
   double lim2 = lim1 / 3;
   if(highCount == 3 && lowCount == 3)
     {
      bool order_condition = (idxlows[0] < idxhighs[0]
                              < idxlows[1] < idxhighs[1]
                              < idxlows[2] < idxhighs[2]);
      bool diff_condition = (
                               MathAbs(lows[0] - highs[0]) > lim1 &&
                               MathAbs(highs[0] - lows[1]) > lim2 &&
                               MathAbs(highs[1] - lows[1]) > lim1 &&
                               MathAbs(highs[1] - lows[2]) > lim2
                            );
      bool pattern_1 = (lows[0] < highs[0] &&
                        lows[1] > lows[0] && lows[1] < highs[0] &&
                        highs[1] > highs[0] &&
                        lows[2] > lows[1] && lows[2] < highs[1] &&
                        highs[2] < highs[1] && highs[2] > lows[2]
                       );

      bool pattern_2 = (lows[0] < highs[0] &&
                        lows[1] > lows[0] && lows[1] < highs[0] &&
                        highs[1] > highs[0] &&
                        lows[2] < lows[1] &&
                        highs[2] < highs[1]
                       );

      if(order_condition && diff_condition && (pattern_1 || pattern_2))
        {
         return 1;
        }
     }

   return 0;
  }

//+------------------------------------------------------------------+

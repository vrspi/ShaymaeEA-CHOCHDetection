
import pandas as pd
import pandas_ta as ta
import pandas as pd
import numpy as np
import plotly.graph_objects as go
from scipy import stats

df = pd.read_csv("EURUSD_Candlestick_1_Hour_BID_04.05.2003-15.04.2023.csv")
df=df[df['volume']!=0]
df.reset_index(drop=True, inplace=True)

df['RSI'] = ta.rsi(df.close, length=12)
df['EMA'] = ta.ema(df.close, length=150)
df.tail()

df=df[0:5000]

EMAsignal = [0]*len(df)
backcandles = 15

for row in range(backcandles, len(df)):
    upt = 1
    dnt = 1
    for i in range(row-backcandles, row+1):
        if max(df.open[i], df.close[i])>=df.EMA[i]:
            dnt=0
        if min(df.open[i], df.close[i])<=df.EMA[i]:
            upt=0
    if upt==1 and dnt==1:
        EMAsignal[row]=3
    elif upt==1:
        EMAsignal[row]=2
    elif dnt==1:
        EMAsignal[row]=1

df['EMASignal'] = EMAsignal

def isPivot(candle, window):
    """
    function that detects if a candle is a pivot/fractal point
    args: candle index, window before and after candle to test if pivot
    returns: 1 if pivot high, 2 if pivot low, 3 if both and 0 default
    """
    if candle-window < 0 or candle+window >= len(df):
        return 0
    
    pivotHigh = 1
    pivotLow = 2
    for i in range(candle-window, candle+window+1):
        if df.iloc[candle].low > df.iloc[i].low:
            pivotLow=0
        if df.iloc[candle].high < df.iloc[i].high:
            pivotHigh=0
    if (pivotHigh and pivotLow):
        return 3
    elif pivotHigh:
        return pivotHigh
    elif pivotLow:
        return pivotLow
    else:
        return 0

window=5
df['isPivot'] = df.apply(lambda x: isPivot(x.name,window), axis=1)

def pointpos(x):
    if x['isPivot']==2:
        return x['low']-1e-3
    elif x['isPivot']==1:
        return x['high']+1e-3
    else:
        return np.nan
df['pointpos'] = df.apply(lambda row: pointpos(row), axis=1)

dfpl = df[300:450]
fig = go.Figure(data=[go.Candlestick(x=dfpl.index,
                open=dfpl['open'],
                high=dfpl['high'],
                low=dfpl['low'],
                close=dfpl['close'])])

fig.add_scatter(x=dfpl.index, y=dfpl['pointpos'], mode="markers",
                marker=dict(size=5, color="MediumPurple"),
                name="pivot")
fig.update_layout(xaxis_rangeslider_visible=False)
fig.show()

def detect_structure(candle, backcandles, window):
    """
    Attention! window should always be greater than the pivot window! to avoid look ahead bias
    """
    localdf = df[candle-backcandles-window:candle-window]  
    highs = localdf[localdf['isPivot'] == 1].high.tail(3).values
    idxhighs = localdf[localdf['isPivot'] == 1].high.tail(3).index
    lows = localdf[localdf['isPivot'] == 2].low.tail(3).values
    idxlows = localdf[localdf['isPivot'] == 2].low.tail(3).index

    pattern_detected = False

    lim1 = 0.005
    lim2 = lim1/3
    if len(highs) == 3 and len(lows) == 3:
        order_condition = (idxlows[0] < idxhighs[0] 
                           < idxlows[1] < idxhighs[1] 
                           < idxlows[2] < idxhighs[2])
        diff_condition = ( 
                            abs(lows[0]-highs[0])>lim1 and 
                            abs(highs[0]-lows[1])>lim2 and
                            abs(highs[1]-lows[1])>lim1 and
                            abs(highs[1]-lows[2])>lim2
                            )
        pattern_1 = (lows[0] < highs[0] and
            lows[1] > lows[0] and lows[1] < highs[0] and
            highs[1] > highs[0] and
            lows[2] > lows[1] and lows[2] < highs[1] and
            highs[2] < highs[1] and highs[2] > lows[2]
            )

        pattern_2 = (lows[0] < highs[0] and
            lows[1] > lows[0] and lows[1] < highs[0] and
            highs[1] > highs[0] and
            lows[2] < lows[1] and
            highs[2] < highs[1] 
            )

        if (order_condition and
            diff_condition and
            (pattern_1 or pattern_2)
        ):
            pattern_detected = True

    if pattern_detected:
        return 1
    else:
        return 0

df['pattern_detected'] = df.index.map(lambda x: detect_structure(x, backcandles=40, window=6))

df[df['pattern_detected']!=0]




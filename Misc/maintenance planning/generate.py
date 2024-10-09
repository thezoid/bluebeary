import datetime

# get the first instance of the weekday in a given month and year
# _year:    the year to calculate for
# _month:   the month of the year to calculate for (1-12)
# _weekday: the day of the week to calculate for (0-6)

def getDay(_year,_month,_weekday):
    d = datetime.datetime(_year, _month, _weekday)
    offset = 1-d.weekday()
    if offset < 0:
        offset+=7
    return d+datetime.timedelta(offset)

targetYear = int(input("Provide the year to generate dates for:\t"))

for i in range(1,13):
    patchTuesday = getDay(targetYear,i,1) + datetime.timedelta(days=7) #get the second tuesday (patch tuesday)
    devDate = patchTuesday + datetime.timedelta(days=2) #thursday after patch tuesday
    prodDate = patchTuesday + datetime.timedelta(days=9) #thursday 1 week after patch tuesday
    print(f"{patchTuesday.strftime('%m/%d')},Patch Tuesday Release,Release is usually 1pm ET\n{devDate.strftime('%m/%d')},Development,\n{prodDate.strftime('%m/%d')},Production,")
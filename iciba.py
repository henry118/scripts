#!/usr/bin/python

import sys
import os.path
import urllib2
import xml.etree.ElementTree as ET

def usage():
    print 'Usage: %s [word]' % os.path.basename(sys.argv[0])

def main(word):
    try:
        ans = urllib2.urlopen('http://dict-co.iciba.com/api/dictionary.php?w=%s' % word)
        root = ET.fromstring(ans.read())
        print '[ %s ]' % root.find('key').text.strip()
        print '------------'
        plist = root.findall('pos')
        alist = root.findall('acceptation')
        if plist != None and alist != None:
            for i in range(0, len(plist)):
                if plist[i].text != None:
                    print plist[i].text.strip(),
                if alist[i].text != None:
                    print alist[i].text.strip()
        for j in root.findall('sent'):
            print '------------'
            print j.find('orig').text.strip()
            print j.find('trans').text.strip()
        print '------------'
    except Exception, e:
        print e

if __name__ == '__main__':
    if len(sys.argv) < 2:
        usage()
    else:
        main(sys.argv[1])

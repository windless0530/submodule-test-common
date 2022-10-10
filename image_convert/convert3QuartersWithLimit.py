import os
from convertBase import process_dir

if '__main__' == __name__:
    num = process_dir(os.path.abspath('.'), "medium", 0.7)
    print 'Done. '
    print 'Totally ' + str(num) + ' files processed.'


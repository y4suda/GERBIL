import parmed as pmd
import sys

name=sys.argv[1]
amber = pmd.load_file(f"./{name}_fixed.top")
amber.save("model.prmtop")


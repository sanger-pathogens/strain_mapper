// Copyright (C) 2022,2023 Genome Research Ltd.

class BcftoolsCallCompare {
    /**
     * A comparison function that takes into account the file extension. It:
     * - Compares contents of *.vcf files, ignoring the header and any rounding/numerical accuracy differences
     * This function is designed to be passed as a closure to Compare.dirsConform.
     */
    public static def compare(expected, actual) {
        def pathStr = "$expected"
        // Check both files exist, or return the right kind of error.
        if (!actual.exists()) {
            return Compare.Result.MISSING
        }
        if (!expected.exists()) {
            return Compare.Result.UNEXPECTED
        }
        // Compare the contents of the files.
        if (pathStr.endsWith(".vcf")) {
            def expectedLines = expected.newReader().lines()
            def actualLines = actual.newReader().lines()
            if (!Vcf.compare(expectedLines, actualLines)) {
                return Compare.Result.INCORRECT
            }
        }
        // Accept them if they got through all that.
        return Compare.Result.ACCEPT
    }
}

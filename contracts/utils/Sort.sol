// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

library Sort {
    function quickSort(uint32[] memory arr, uint left, uint right) internal pure {
        if (left >= right) return;
        uint32 p = arr[(left + right) / 2]; // p = the pivot element
        uint i = left;
        uint j = right;
        while (i < j) {
            while (arr[i] < p) ++i;
            while (arr[j] > p) --j; // arr[j] > p means p still to the left, so j > 0
            if (arr[i] > arr[j]) (arr[i], arr[j]) = (arr[j], arr[i]);
            else ++i;
        }

        // Note --j was only done when a[j] > p.  So we know: a[j] == p, a[<j] <= p, a[>j] > p
        if (j > left) quickSort(arr, left, j - 1); // j > left, so j > 0
        quickSort(arr, j + 1, right);
    }
}

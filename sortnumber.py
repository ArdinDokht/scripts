!/usr/bin/env python3

def bubble_sort(arr):
    n = len(arr)
    for i in range(n):
        for j in range(0, n - i - 1):
            if arr[j] > arr[j + 1]:
                arr[j], arr[j + 1] = arr[j + 1], arr[j]
    return arr

if __name__ == "__main__":
    numbers = []

    for i in range(20):
        try:
            num = int(input(f"Enter a valid number ({i+1}/20): "))
            numbers.append(num)
        except ValueError:
            print("Invalid input! Please enter a valid integer.")
            break

    sorted_numbers = bubble_sort(numbers)

    print("Sorted numbers:", sorted_numbers)

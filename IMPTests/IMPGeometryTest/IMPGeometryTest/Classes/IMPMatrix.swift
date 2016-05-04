//
//  IMPMatrix.swift
//  Buckets
//
//  Created by Mauricio Santos on 4/11/15.
//  Copyright (c) 2015 Mauricio Santos. All rights reserved.
//

import Foundation
import simd

extension matrix_float4x4 {
    public func toIMPMatrix() -> IMPMatrix<Float> {
        
        let m0 = self.columns.0
        let m1 = self.columns.1
        let m2 = self.columns.2
        let m3 = self.columns.3
        
        let grid = [
            m0.x, m1.x, m2.x, m3.x,
            m0.y, m1.y, m2.y, m3.y,
            m0.z, m1.z, m2.z, m3.z,
            m0.w, m1.w, m2.w, m3.w,
            ]
        
        return IMPMatrix(rows: 4, columns: 4, grid: grid)
    }
}

/// A Matrix is a fixed size generic 2D collection.
/// You can set and get elements using subscript notation. Example:
/// `matrix[row, column] = value`
///
/// This collection also provides linear algebra functions and operators such as
/// `inverse()`, `+` and `*` using Apple's Accelerate framework. Please note that
/// these operations are designed to work exclusively with `Double` matrices.
/// Check the `Functions` section for more information.
///
/// Conforms to `SequenceType`, `MutableCollectionType`,
/// `ArrayLiteralConvertible`, `Printable` and `DebugPrintable`.
public struct IMPMatrix<T> {
    
    // MARK: Creating a Matrix
    
    /// Constructs a new matrix with all positions set to the specified value.
    public init(rows: Int, columns: Int, repeatedValue: T) {
        if rows <= 0 {
            fatalError("Can't create matrix. Invalid number of rows.")
        }
        if columns <= 0 {
            fatalError("Can't create matrix. Invalid number of columns")
        }
        
        self.rows = rows
        self.columns = columns
        grid = Array(count: rows * columns, repeatedValue: repeatedValue)
    }
    
    /// Constructs a new matrix using a 1D array in row-major order.
    ///
    /// `Matrix[i,j] == grid[i*columns + j]`
    public init(rows: Int, columns: Int, grid: [T]) {
        if grid.count != rows*columns {
            fatalError("Can't create matrix. grid.count must equal rows*columns")
        }
        self.rows = rows
        self.columns = columns
        self.grid = grid
    }
    
    /// Constructs a new matrix using a 2D array.
    /// All columns must be the same size, otherwise an error is triggered.
    public init(_ rowsArray: [[T]]) {
        let rows = rowsArray.count
        if rows <= 0 {
            fatalError("Can't create an empty matrix.")
        }
        if rowsArray[0].count <= 0 {
            fatalError("Can't create a matrix column with no elements.")
        }
        let columns = rowsArray[0].count
        for subArray in rowsArray {
            if subArray.count != columns {
                fatalError("Can't create a matrix with different sixzed columns")
            }
        }
        var grid = Array<T>()
        grid.reserveCapacity(rows*columns)
        for i in 0..<rows {
            for j in 0..<columns {
                grid.append(rowsArray[i][j])
            }
        }
        self.init(rows: rows, columns: columns, grid: grid)
    }
    
    // MARK: Querying a Matrix
    
    /// The number of rows in the matrix.
    public let rows: Int
    
    /// The number of columns in the matrix.
    public let columns: Int
    
    /// The one-dimensional array backing the matrix in row-major order.
    ///
    /// `Matrix[i,j] == grid[i*columns + j]`
    public internal(set) var grid: [T]
    
    /// Returns the transpose of the matrix.
    public var transpose: IMPMatrix<T> {
        var result = IMPMatrix(rows: columns, columns: rows, repeatedValue: self[0,0])
        for i in 0..<rows {
            for j in 0..<columns {
                result[j,i] = self[i,j]
            }
        }
        return result
    }
    
    // MARK: Getting and Setting elements
    
    // Provides random access for getting and setting elements using square bracket notation.
    // The first argument is the row number.
    // The first argument is the column number.
    public subscript(row: Int, column: Int) -> T {
        get {
            if !indexIsValidForRow(row, column: column) {
                fatalError("Index out of range")
            }
            return grid[(row * columns) + column]
        }
        set {
            if !indexIsValidForRow(row, column: column) {
                fatalError("Index out of range")
            }
            grid[(row * columns) + column] = newValue
        }
    }
    
    // MARK: Private Properties and Helper Methods
    
    private func indexIsValidForRow(row: Int, column: Int) -> Bool {
        return row >= 0 && row < rows && column >= 0 && column < columns
    }
}

// MARK: -

extension IMPMatrix: SequenceType {
    
    // MARK: SequenceType Protocol Conformance
    
    /// Provides for-in loop functionality.
    /// Returns the elements in row-major order.
    ///
    /// - returns: A generator over the elements.
    public func generate() -> AnyGenerator<T> {
        return AnyGenerator(IndexingGenerator(self))
    }
}

extension IMPMatrix: MutableCollectionType {
    
    // MARK: MutableCollectionType Protocol Conformance
    
    public typealias MatrixIndex = Int
    
    /// Always zero, which is the index of the first element when non-empty.
    public var startIndex : MatrixIndex {
        return 0
    }
    
    /// Always `rows*columns`, which is the successor of the last valid subscript argument.
    public var endIndex : MatrixIndex {
        return rows*columns
    }
    
    /// Provides random access to elements using the matrix back-end array coordinate
    /// in row-major order.
    /// Matrix[row, column] is preferred.
    public subscript(position: MatrixIndex) -> T {
        get {
            return self[position/columns, position % columns]
        }
        set {
            self[position/columns, position % columns] = newValue
        }
    }
}

extension IMPMatrix: ArrayLiteralConvertible {
    
    // MARK: ArrayLiteralConvertible Protocol Conformance
    
    /// Constructs a matrix using an array literal.
    public init(arrayLiteral elements: Array<T>...) {
        self.init(elements)
    }
}

extension IMPMatrix: CustomStringConvertible {
    
    // MARK: CustomStringConvertible Protocol Conformance
    
    /// A string containing a suitable textual
    /// representation of the matrix.
    public var description: String {
        var result = "[\n"
        for i in 0..<rows {
            if i != 0 {
                result += ", "
            }
            let start = i*columns
            let end = start + columns
            result += "\n[" + grid[start..<end].map {"\($0)"}.joinWithSeparator(", ") + "]"
        }
        result += "]"
        return result
    }
}

// MARK: Matrix Standard Operators

/// Returns `true` if and only if the matrices contain the same elements
/// at the same coordinates.
/// The underlying elements must conform to the `Equatable` protocol.
public func ==<T: Equatable>(lhs: IMPMatrix<T>, rhs: IMPMatrix<T>) -> Bool {
    return lhs.columns == rhs.columns && lhs.rows == rhs.rows &&
        lhs.grid == rhs.grid
}

public func !=<T: Equatable>(lhs: IMPMatrix<T>, rhs: IMPMatrix<T>) -> Bool {
    return !(lhs == rhs)
}
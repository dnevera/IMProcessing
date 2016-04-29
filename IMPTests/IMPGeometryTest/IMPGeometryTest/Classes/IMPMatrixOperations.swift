//
//  IMPMatrixOperators.swift
//  Buckets
//
//  Created by Mauricio Santos on 2016-02-03.
//  Copyright © 2016 Mauricio Santos. All rights reserved.
//

#if !os(watchOS)
    import Foundation
    import Accelerate
    
    // MARK: Matrix Linear Algebra Operations
    
    // Inversion
    
    /// Returns the inverse of the given matrix or nil if it doesn't exist.
    /// If the argument is a non-square matrix an error is triggered.
    public func inverse(matrix: IMPMatrix<Double>) -> IMPMatrix<Double>? {
        if matrix.columns != matrix.rows {
            fatalError("Can't invert a non-square matrix.")
        }
        var invMatrix = matrix
        var N = __CLPK_integer(sqrt(Double(invMatrix.grid.count)))
        var pivots = [__CLPK_integer](count: Int(N), repeatedValue: 0)
        var workspace = [Double](count: Int(N), repeatedValue: 0.0)
        var error : __CLPK_integer = 0
        // LU factorization
        dgetrf_(&N, &N, &invMatrix.grid, &N, &pivots, &error)
        if error != 0 {
            return nil
        }
        // Matrix inversion
        dgetri_(&N, &invMatrix.grid, &N, &pivots, &workspace, &N, &error)
        if error != 0 {
            return nil
        }
        return invMatrix
    }
    
    //Addition
    
    /// Performs matrix and matrix addition.
    public func +(lhs: IMPMatrix<Float>, rhs: IMPMatrix<Float>) -> IMPMatrix<Float> {
        if lhs.rows != rhs.rows || lhs.columns != rhs.columns {
            fatalError("Impossible to add different size matrices")
        }
        var result = rhs
        cblas_saxpy(Int32(lhs.grid.count), 1.0, lhs.grid, 1, &(result.grid), 1)
        return result
    }
    
    /// Performs matrix and matrix addition.
    public func +=(inout lhs: IMPMatrix<Float>, rhs: IMPMatrix<Float>) {
        lhs.grid = (lhs + rhs).grid
    }
    
    /// Performs matrix and scalar addition.
    public func +(lhs: IMPMatrix<Float>, rhs: Float) -> IMPMatrix<Float> {
        let scalar = rhs
        var result = IMPMatrix<Float>(rows: lhs.rows, columns: lhs.columns, repeatedValue: scalar)
        cblas_saxpy(Int32(lhs.grid.count), 1, lhs.grid, 1, &(result.grid), 1)
        return result
    }
    
    /// Performs scalar and matrix addition.
    public func +(lhs: Float, rhs: IMPMatrix<Float>) -> IMPMatrix<Float> {
        return rhs + lhs
    }
    
    /// Performs matrix and scalar addition.
    public func +=(inout lhs: IMPMatrix<Float>, rhs: Float) {
        lhs.grid = (lhs + rhs).grid
    }
    
    // Subtraction
    
    /// Performs matrix and matrix subtraction.
    public func -(lhs: IMPMatrix<Float>, rhs: IMPMatrix<Float>) -> IMPMatrix<Float> {
        if lhs.rows != rhs.rows || lhs.columns != rhs.columns {
            fatalError("Impossible to substract different size matrices.")
        }
        var result = lhs
        cblas_saxpy(Int32(lhs.grid.count), -1.0, rhs.grid, 1, &(result.grid), 1)
        return result
    }
    
    /// Performs matrix and matrix subtraction.
    public func -=(inout lhs: IMPMatrix<Float>, rhs: IMPMatrix<Float>) {
        lhs.grid = (lhs - rhs).grid
    }
    
    /// Performs matrix and scalar subtraction.
    public func -(lhs: IMPMatrix<Float>, rhs: Float) -> IMPMatrix<Float> {
        return lhs + (-rhs)
    }
    
    /// Performs matrix and scalar subtraction.
    public func -=(inout lhs: IMPMatrix<Float>, rhs: Float) {
        lhs.grid = (lhs - rhs).grid
    }
    
    // Negation
    
    /// Negates all the values in a matrix.
    public prefix func -(m: IMPMatrix<Float>) -> IMPMatrix<Float> {
        var result = m
        cblas_sscal(Int32(m.grid.count), -1.0, &(result.grid), 1)
        return result
    }
    
    // Multiplication
    
    /// Performs matrix and matrix multiplication.
    /// The first argument's number of columns must match the second argument's number of rows,
    /// otherwise an error is triggered.
    public func *(lhs: IMPMatrix<Float>, rhs: IMPMatrix<Float>) -> IMPMatrix<Float> {
        if lhs.columns != rhs.rows {
            fatalError("Matrix product is undefined: first.columns != second.rows")
        }
        var result = IMPMatrix<Float>(rows: lhs.rows, columns: rhs.columns, repeatedValue: 0.0)
        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasNoTrans, Int32(lhs.rows), Int32(rhs.columns),
                    Int32(lhs.columns), 1.0, lhs.grid, Int32(lhs.columns), rhs.grid, Int32(rhs.columns),
                    0.0, &(result.grid), Int32(result.columns))
        
        return result
    }
    
    /// Performs matrix and scalar multiplication.
    public func *(lhs: IMPMatrix<Float>, rhs: Float) -> IMPMatrix<Float> {
        var result = lhs
        cblas_sscal(Int32(lhs.grid.count), rhs, &(result.grid), 1)
        return result
    }
    
    /// Performs scalar and matrix multiplication.
    public func *(lhs: Float, rhs: IMPMatrix<Float>) -> IMPMatrix<Float> {
        return rhs*lhs
    }
    
    /// Performs matrix and scalar multiplication.
    public func *=(inout lhs: IMPMatrix<Float>, rhs: Float) {
        lhs.grid = (lhs*rhs).grid
    }
    
    // Division
    
    /// Performs matrix and scalar division.
    public func /(lhs: IMPMatrix<Float>, rhs: Float) -> IMPMatrix<Float> {
        return lhs * (1/rhs)
    }
    
    /// Performs matrix and scalar division.
    public func /=(inout lhs: IMPMatrix<Float>, rhs: Float) {
        lhs.grid = (lhs/rhs).grid
    }
#endif
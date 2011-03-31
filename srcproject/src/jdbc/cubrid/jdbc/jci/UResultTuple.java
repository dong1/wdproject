/*
 * Copyright (C) 2008 Search Solution Corporation. All rights reserved by Search Solution. 
 *
 * Redistribution and use in source and binary forms, with or without modification, 
 * are permitted provided that the following conditions are met: 
 *
 * - Redistributions of source code must retain the above copyright notice, 
 *   this list of conditions and the following disclaimer. 
 *
 * - Redistributions in binary form must reproduce the above copyright notice, 
 *   this list of conditions and the following disclaimer in the documentation 
 *   and/or other materials provided with the distribution. 
 *
 * - Neither the name of the <ORGANIZATION> nor the names of its contributors 
 *   may be used to endorse or promote products derived from this software without 
 *   specific prior written permission. 
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND 
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED 
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. 
 * IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, 
 * INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
 * BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, 
 * OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY 
 * OF SUCH DAMAGE. 
 *
 */

/**
 * Title:        CUBRID Java Client Interface<p>
 * Description:  CUBRID Java Client Interface<p>
 * @version 2.0
 */

package @CUBRID_JCI@;

import @CUBRID_SQL@.CUBRIDOID;

/**
 * query statement, getSchemaInfo, getByOid�� ������ �� ������� Result Set��
 * manage�ϱ� ���� class�̴�. �� column���� Object array�� �����Ǹ� column
 * value�� null������ check�ϴ� boolean type array�� ������ �ִ�.
 * 
 * since 1.0
 */

class UResultTuple
{
  private int index;
  private CUBRIDOID oid;
  // private boolean wasNull[] = {};
  private Object attributes[];

  UResultTuple(int tupleIndex, int attributeNumber)
  {
    index = tupleIndex;
    attributes = new Object[attributeNumber];
    // wasNull = new boolean[attributeNumber];
  }

  /*
   * Result Set�� clear��Ű�� ���� ���ȴ�.
   */

  void close()
  {
    for (int i = 0; attributes != null && i < attributes.length; i++)
      attributes[i] = null;
    attributes = null;
    // wasNull = null;
    oid = null;
  }

  /*
   * index��° column value�� return�Ѵ�.
   */

  Object getAttribute(int tIndex)
  {
    /*
     * if (tIndex < 0 || attributes == null || tIndex >= attributes.length)
     * return null;
     */
    return attributes[tIndex];
  }

  /*
   * ���� tuple�� oid���� return�Ѵ�.
   */

  CUBRIDOID getOid()
  {
    return oid;
  }

  boolean oidIsIncluded()
  {
    if (oid == null)
      return false;
    return true;
  }

  /*
   * ���� tuple�� index��° column value�� data�� set�Ѵ�.
   */

  void setAttribute(int tIndex, Object data)
  {
    /*
     * if (wasNull == null || attributes == null || tIndex < 0 || tIndex >
     * wasNull.length - 1 || tIndex > attributes.length - 1) { return; }
     * wasNull[tIndex] = (data == null) ? true : false;
     */

    attributes[tIndex] = data;
  }

  /*
   * ���� tuple�� oid�� set�Ѵ�.
   */

  void setOid(CUBRIDOID o)
  {
    oid = o;
  }

  /*
   * tuple index�� return�Ѵ�.
   */

  int tupleNumber()
  {
    return index;
  }

  /*
   * ���� tuple�� index��° column�� null������ return�Ѵ�.
   * 
   * 
   * boolean wasNull(int tIndex) { return ((wasNull != null) ? wasNull[tIndex] :
   * false); }
   */
}
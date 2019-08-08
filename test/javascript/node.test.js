import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Node from 'forkMonitorApp/components/node';

describe('Node', () => {
  const chaintip = {
    block: {
      hash: "abcd",
      height: 500000,
      timestamp: 1,
      work: 86.000001
    }
  }

  const node = {id: 1, name: "Bitcoin Core", version: 170100, height: 500000, unreachable_since: null, ibd: false};

  let wrapper;

  beforeAll(() => {
    wrapper = shallow(<Node
      key={ 0 }
      node={ node }
      chaintip={ chaintip }
    />)
  });

  describe('Node', () => {

    test('should contain the name', () => {
      expect(wrapper.text()).toContain("<NodeName />");
    });

  });

});

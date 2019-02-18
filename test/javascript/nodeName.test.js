import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import NodeName from 'forkMonitorApp/components/nodeName';

const chaintip = {
  hash: "abcd",
  height: 500000,
  timestamp: 1,
  work: 86.000001
}

let wrapper;

describe('NodeName', () => {
  const node = {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false};

  beforeAll(() => {
    wrapper = shallow(<NodeName
      key={ 0 }
      node={ node }
    />)
  });

  test('should display version', () => {
    expect(wrapper.find('.node-version')).toHaveLength(1);
    expect(wrapper.find('.node-version').text()).toContain("0.17.1");
  });
});

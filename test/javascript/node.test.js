import React from 'react';
import ReactDOM from 'react-dom';

import { shallow, configure } from 'enzyme';
import Adapter from 'enzyme-adapter-react-16';
configure({ adapter: new Adapter() });

import Node from 'forkMonitorApp/components/node';

const chaintip = {
  hash: "abcd",
  height: 500000,
  timestamp: 1,
  work: 86.000001
}

let wrapper;

describe('Node', () => {
  const node = {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false};

  beforeAll(() => {
    wrapper = shallow(<Node
      key={ 0 }
      node={ node }
    />)
  });

  test('should display version', () => {
    expect(wrapper.find('.node-version')).toHaveLength(1);
    expect(wrapper.find('.node-version').text()).toContain("0.17.1");
  });
});

describe('Sync', () => {
  const node = {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false};

  test('should be indicated', () => {
    wrapper = shallow(<Node
      key={ 0 }
      node={ node }
    />)
    expect(wrapper.find("Badge")).toHaveLength(0);
    node.ibd = true;
    wrapper = shallow(<Node
      key={ 0 }
      node={ node }
    />)
    expect(wrapper.find("Badge")).toHaveLength(1);
  });
});

describe('Reachability', () => {
  const node = {id: 1, name: "Bitcoin Core", version: 170100, best_block: chaintip, unreachable_since: null, ibd: false};

  test('should indicate when unreachable', () => {
    node.unreachable_since = "2019-02-14T17:54:31.959Z";
    wrapper = shallow(<Node
      key={ 0 }
      node={ node }
    />)
    expect(wrapper.find("Badge")).toHaveLength(1);
  });
});
